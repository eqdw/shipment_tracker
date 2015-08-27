class FeatureReviewWithDependentVersions < SimpleDelegator
  def initialize(feature_review)
    super(feature_review)
    @feature_review = feature_review
  end

  def dependent_versions(git_repository)
    versions.flat_map { |version|
      dependent_versions = GitRepository.new(git_repository).get_dependent_commits(version).map(&:id)
      dependent_versions << version unless dependent_versions.empty?
    }.compact.uniq
  end
end
