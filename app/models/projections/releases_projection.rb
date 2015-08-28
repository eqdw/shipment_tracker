require 'git_repository'
require 'events/jira_event'
require 'release'
require 'ticket'
require 'release_with_status'

module Projections
  class ReleasesProjection
    attr_reader :pending_releases, :deployed_releases

    def initialize(per_page:, git_repository:, app_name:)
      @per_page = per_page
      @git_repository = git_repository
      @app_name = app_name

      @deploy_repository = Repositories::DeployRepository.new
      @pending_releases = []
      @deployed_releases = []

      build_and_categorize_releases
    end

    # def apply_all(events)
    #   events.each do |event|
    #     apply(event)
    #   end
    #   categorize_releases
    # end

    private

    # def apply(event)
    #   case event
    #   when Events::JiraEvent
    #     associate_releases_with_feature_review(event)
    #     # tickets_projection.apply(event)
    #   end
    # end
    attr_reader :app_name, :deploy_repository, :git_repository

    def production_deploys
      @production_deploys ||= deploy_repository.deploys_for_versions(versions, environment: 'production')
    end

    def commits
      @commits ||= @git_repository.recent_commits(@per_page)
    end

    def versions
      @versions ||= commits.map(&:id)
    end

    def production_deploy_for_commit(commit)
      @production_deploy_for_commit ||= production_deploys.detect { |deployment|
        deployment.version == commit.id
      }
    end

    def build_and_categorize_releases
      commits.each { |commit|
        # if commit is deployed all subsequent (earlier) commits have been deployed too
        deploy = production_deploy_for_commit(commit) if production_deploy_for_commit(commit)
        if deploy
          @deployed_releases << create_release_from(
            commit: commit, deploy: production_deploy_for_commit(commit)
          )
        else
          @pending_releases << create_release_from(commit: commit)
        end
      }
    end

    def create_release_from(commit:, deploy: nil)
      release = Release.new(
        version: commit.id,
        production_deploy_time: deploy.try(:event_created_at),
        subject: commit.subject_line,
      )

      ReleaseWithStatus.new(
        release: release,
        git_repository: git_repository,
      )
    end

    # def associate_dependent_releases_with_feature_review
    #   feature_review_commit_versions.each do |sha|
    #     @git_repository.get_dependent_commits(sha).each do |dependent_commit|
    #       @feature_reviews[dependent_commit.id] = @feature_reviews[sha]
    #     end
    #   end
    # end

    # def feature_review_commit_versions
    #   @feature_reviews.keys
    # end

    # def feature_review_for_commit(commit_oid)
    #   @feature_reviews.fetch(commit_oid, key: nil, path: nil)
    # end

    # def associate_feature_review(commit_oid, feature_review)
    #   @feature_reviews[commit_oid] = feature_review
    # end

    # def associate_releases_with_feature_review(jira_event)
    #   FeatureReviewLocation.from_text(jira_event.comment).each do |location|
    #     commit_oids = extract_relevant_commit_from_location(location)
    #     commit_oids.each do |commit_oid|
    #       associate_feature_review(commit_oid, key: jira_event.key, path: location.path)
    #     end
    #   end
    # end

    # def extract_relevant_commit_from_location(feature_review_location)
    #   feature_review_location.versions.select { |commit_oid|
    #     commits.find { |c| c.id == commit_oid }
    #   }
    # end
  end
end
