require 'release'

module Queries
  class ReleasesQuery
    attr_reader :pending_releases, :deployed_releases

    def initialize(per_page:, git_repo:, app_name:)
      @per_page = per_page
      @git_repository = git_repo
      @app_name = app_name

      @deploy_repository = Repositories::DeployRepository.new
      @ticket_repository = Repositories::TicketRepository.new
      @feature_review_factory = Factories::FeatureReviewFactory.new

      @pending_releases = []
      @deployed_releases = []

      build_and_categorize_releases
    end

    private

    attr_reader :app_name, :deploy_repository, :feature_review_factory, :git_repository, :ticket_repository

    def production_deploys
      @production_deploys ||= deploy_repository.deploys_for_versions(versions, environment: 'production')
    end

    def commits
      @commits ||= @git_repository.recent_commits_on_main_branch(@per_page)
    end

    def feature_reviews
      @feature_reviews ||= feature_review_factory.create_from_tickets(tickets)
    end

    def tickets
      @tickets ||= ticket_repository.tickets_for_versions(associated_versions)
    end

    def versions
      commits.map(&:id)
    end

    def associated_versions
      commits.map(&:associated_ids).flatten.uniq
    end

    def production_deploy_for_commit(commit)
      production_deploys.detect { |deployment|
        deployment.version == commit.id
      }
    end

    def build_and_categorize_releases
      deployed = false
      commits.each { |commit|
        deploy_for_commit = production_deploy_for_commit(commit)
        deployed = true if deploy_for_commit # A deploy means all subsequent (earlier) commits are deployed.
        if deployed
          @deployed_releases << create_release_from(commit: commit, deploy: deploy_for_commit)
        else
          @pending_releases << create_release_from(commit: commit)
        end
      }
    end

    def create_release_from(commit:, deploy: nil)
      decorated_feature_reviews = feature_reviews
                                  .select { |fr| (fr.versions & commit.associated_ids).present? }
                                  .map { |fr| decorate_feature_review(fr) }

      Release.new(
        commit: commit,
        production_deploy_time: deploy.try(:event_created_at),
        subject: commit.subject_line,
        feature_reviews: decorated_feature_reviews,
      )
    end

    def decorate_feature_review(feature_review)
      FeatureReviewWithStatuses.new(
        feature_review,
        tickets: tickets.select { |t| t.paths.include?(feature_review.path) },
      )
    end
  end
end
