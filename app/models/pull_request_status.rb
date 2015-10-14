require 'octokit'
require 'active_support/json'
require 'feature_review_with_statuses'
require 'repositories/ticket_repository'
require 'factories/feature_review_factory'

class PullRequestStatus
  def initialize(token: Rails.application.config.github_access_token,
                 routes: Rails.application.routes.url_helpers)
    @token = token
    @routes = routes
    @ticket_repository = Repositories::TicketRepository.new
    @feature_review_factory = Factories::FeatureReviewFactory.new
  end

  def update(repo_url:, sha:)
    repo_url = repo_url.sub(/\.git$/, '')
    feature_reviews = decorated_feature_reviews(sha)
    status, description = *status_for(feature_reviews).values_at(:status, :description)
    target_url = target_url_for(
      repo_url: repo_url,
      sha: sha,
      feature_reviews: feature_reviews)
    publish_status(
      repo_url: repo_url,
      sha: sha,
      status: status,
      description: description,
      target_url: target_url)
  end

  def reset(repo_url:, sha:)
    publish_status(
      repo_url: repo_url,
      sha: sha,
      status: reset_status[:status],
      description: reset_status[:description])
  end

  private

  attr_reader :token, :routes, :ticket_repository, :feature_review_factory

  def decorated_feature_reviews(commit)
    tickets = ticket_repository.tickets_for_versions([commit])
    feature_reviews = feature_review_factory.create_from_tickets(tickets)
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
    if feature_reviews.empty?
      routes.new_feature_reviews_url(url_opts)
    elsif feature_reviews.length == 1
      routes.root_url(url_opts).chomp('/') + feature_reviews.first.path
    else
      repo_name = repo_url.split('/').last
      routes.search_feature_reviews_url(url_opts.merge(application: repo_name, versions: sha))
    end
  end

  def status_for(feature_reviews)
    if feature_reviews.empty?
      not_reviewed_status
    elsif feature_reviews.any?(&:approved?)
      approved_status
    else
      unapproved_status
    end
  end

  def not_reviewed_status
    {
      status: 'failure',
      description: 'No Feature Review found',
    }
  end

  def approved_status
    {
      status: 'success',
      description: 'Approved Feature Review found',
    }
  end

  def unapproved_status
    {
      status: 'pending',
      description: 'Awaiting approval for Feature Review',
    }
  end

  def reset_status
    {
      status: 'pending',
      description: 'Searching for Feature Review',
    }
  end
end
