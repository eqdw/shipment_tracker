require 'active_support/json'
require 'octokit'

require 'factories/feature_review_factory'
require 'feature_review_with_statuses'
require 'repositories/ticket_repository'
require 'repositories/deploy_repository'

class PullRequestStatus
  def initialize(token: Rails.application.config.github_access_token)
    @token = token
    @routes = Rails.application.routes.url_helpers
  end

  def update(repo_url:, sha:)
    repo_url = repo_url.chomp('.git')
    feature_reviews = decorated_feature_reviews(sha)
    status, description = status_for(feature_reviews).values_at(:status, :description)

    target_url = target_url_for(
      repo_url: repo_url,
      sha: sha,
      feature_reviews: feature_reviews,
    )

    publish_status(
      repo_url: repo_url,
      sha: sha,
      status: status,
      description: description,
      target_url: target_url,
    )
  end

  def reset(repo_url:, sha:)
    publish_status(
      repo_url: repo_url,
      sha: sha,
      status: searching_status[:status],
      description: searching_status[:description],
    )
  end

  private

  attr_reader :token, :routes

  def decorated_feature_reviews(sha)
    tickets = Repositories::TicketRepository.new.tickets_for_versions([sha])
    feature_reviews = Factories::FeatureReviewFactory.new
                      .create_from_tickets(tickets)
                      .select { |fr| fr.versions.include?(sha) }
    feature_reviews.map do |feature_review|
      FeatureReviewWithStatuses.new(
        feature_review,
        tickets: tickets.select { |t| t.paths.include?(feature_review.path) },
      )
    end
  end

  def publish_status(repo_url:, sha:, status:, description:, target_url: nil)
    client = Octokit::Client.new(access_token: token)
    repo = Octokit::Repository.from_url(repo_url)
    client.create_status(repo, sha, status,
      context: 'shipment-tracker',
      target_url: target_url,
      description: description)
  end

  def target_url_for(repo_url:, sha:, feature_reviews:)
    url_opts = { protocol: 'https' }
    repo_name = repo_url.split('/').last
    last_staging_deploy = Repositories::DeployRepository.new.last_staging_deploy_for_version(sha)

    if feature_reviews.empty?
      url_opts.merge!(uat_url: last_staging_deploy.server) if last_staging_deploy
      routes.feature_reviews_url(url_opts.merge(apps: { repo_name => sha }))
    elsif feature_reviews.length == 1
      routes.root_url(url_opts).chomp('/') + feature_reviews.first.path
    else
      routes.search_feature_reviews_url(url_opts.merge(application: repo_name, version: sha))
    end
  end

  def status_for(feature_reviews)
    if feature_reviews.empty?
      not_found_status
    elsif feature_reviews.any?(&:approved?)
      approved_status
    else
      not_approved_status
    end
  end

  def not_found_status
    {
      status: 'failure',
      description: "No Feature Review found. Click 'Details' to create one.",
    }
  end

  def approved_status
    {
      status: 'success',
      description: 'Approved Feature Review found',
    }
  end

  def not_approved_status
    {
      status: 'pending',
      description: 'Awaiting approval for Feature Review',
    }
  end

  def searching_status
    {
      status: 'pending',
      description: 'Searching for Feature Review',
    }
  end
end
