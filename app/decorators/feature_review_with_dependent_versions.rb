class FeatureReviewWithDependentVersions < SimpleDelegator
  def initialize(feature_review)
    super(feature_review)
    @feature_review = feature_review
  end

  def dependent_versions(git_repository)
    versions.flat_map { |version|
      if git_repository.exists?(version) # version might be for another repository
        git_repository.get_dependent_commits(version).map(&:id) << version
      else
        []
      end
    }.compact.uniq
  end
end
