require 'feature_review_with_statuses'
require 'repositories/build_repository'
require 'repositories/deploy_repository'
require 'repositories/manual_test_repository'
require 'repositories/ticket_repository'
require 'repositories/uatest_repository'

module Queries
  class FeatureReviewQuery
    attr_reader :feature_review_with_statuses

    def initialize(feature_review, at:)
      @build_repository = Repositories::BuildRepository.new
      @deploy_repository = Repositories::DeployRepository.new
      @manual_test_repository = Repositories::ManualTestRepository.new
      @ticket_repository = Repositories::TicketRepository.new
      @uatest_repository = Repositories::UatestRepository.new
      @feature_review = feature_review
      @time = at

      build_feature_review_with_statuses
    end

    private

    attr_reader :build_repository, :deploy_repository, :manual_test_repository,
      :ticket_repository, :uatest_repository, :feature_review, :time

    def build_feature_review_with_statuses
      @feature_review_with_statuses = FeatureReviewWithStatuses.new(
        feature_review,
        builds: builds,
        deploys: deploys,
        qa_submission: qa_submission,
        tickets: tickets,
        uatest: uatest,
        at: time,
      )
    end

    def builds
      build_repository.builds_for(
        apps: feature_review.app_versions,
        at: time)
    end

    def deploys
      deploy_repository.deploys_for(
        apps: feature_review.app_versions,
        server: feature_review.uat_host,
        at: time)
    end

    def qa_submission
      manual_test_repository.qa_submission_for(
        versions: feature_review.versions,
        at: time)
    end

    def tickets
      ticket_repository.tickets_for_path(feature_review.path, at: time)
    end

    def uatest
      uatest_repository.uatest_for(
        versions: feature_review.versions,
        server: feature_review.uat_host,
        at: time)
    end
  end
end
