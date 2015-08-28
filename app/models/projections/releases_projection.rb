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

    private

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
  end
end
