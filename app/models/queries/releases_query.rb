require 'release'

module Queries
  class ReleasesQuery
    attr_reader :pending_releases, :deployed_releases

    def initialize(per_page:, git_repo:, app_name:)
      @per_page = per_page
      @git_repository = git_repo
      @app_name = app_name

      @deploy_repository = Repositories::DeployRepository.new
      @feature_review_repository = Repositories::FeatureReviewRepository.new

      @pending_releases = []
      @deployed_releases = []

      build_and_categorize_releases
    end

    private

    attr_reader :app_name, :deploy_repository, :feature_review_repository, :git_repository

    def production_deploys
      @production_deploys ||= deploy_repository.deploys_for_versions(versions, environment: 'production')
    end

    def commits
      @commits ||= @git_repository.recent_commits_on_main_branch(@per_page)
    end

    def feature_reviews
      @feature_reviews ||= feature_review_repository.feature_reviews_for_versions(associated_versions)
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
      Release.new(
        commit: commit,
        production_deploy_time: deploy.try(:event_created_at),
        subject: commit.subject_line,
        feature_reviews: feature_reviews.select { |fr| (fr.versions & commit.associated_ids).present? },
      )
    end
  end
end
