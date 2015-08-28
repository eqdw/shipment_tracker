require 'repositories/feature_review_repository'

module Queries
  class ReleaseQuery
    def initialize(release:, git_repository:, at: Time.now)
      @release = release
      @time = at

      @feature_review_repository = Repositories::FeatureReviewRepository.new
      @git_repository = git_repository
    end

    def feature_reviews
      feature_reviews_with_dependent_versions
        .select { |fr| fr.dependent_versions(git_repository).include?(release.version) }
        .map { |fr| FeatureReviewWithStatuses.new(fr, at: time) }
    end

    private

    attr_reader :feature_review_repository, :git_repository, :release, :time

    def feature_reviews_with_dependent_versions
      raw_feature_reviews.map { |fr| FeatureReviewWithDependentVersions.new(fr) }
    end

    def raw_feature_reviews
      @feature_reviews ||= feature_review_repository.feature_reviews_for(
        versions: associated_versions,
        at: time,
      )
    end

    def associated_versions
      versions = descendant_versions.push(release.version)
      versions.push(parent_version) if git_repository.merge?(release.version)
      versions
    end

    def descendant_versions
      git_repository.get_descendant_commits_of_branch(release.version).map(&:id)
    end

    def parent_version
      git_repository.branch_parent(release.version)
    end
  end
end
