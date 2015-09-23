require 'repositories/feature_review_repository'

module Queries
  class ReleaseQuery
    def initialize(release:, git_repository:, at: Time.current)
      @release = release
      @time = at

      @feature_review_repository = Repositories::FeatureReviewRepository.new
      @git_repository = git_repository
    end

    def feature_reviews
      feature_reviews_with_dependent_versions.select { |fr|
        fr.dependent_versions(git_repository).include?(release.version)
      }
    end

    private

    attr_reader :feature_review_repository, :git_repository, :release, :time

    def feature_reviews_with_dependent_versions
      raw_feature_reviews.map { |fr| FeatureReviewWithDependentVersions.new(fr) }
    end

    def raw_feature_reviews
      @feature_reviews ||= feature_review_repository.feature_reviews_for_versions(
        associated_versions,
        at: time,
      )
    end

    def associated_versions
      versions = [release.version]
      versions.push(release.commit.parent_ids.second)
      versions.compact
    end
  end
end
