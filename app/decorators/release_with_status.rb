class ReleaseWithStatus < SimpleDelegator
  attr_reader :feature_reviews

  def initialize(release:, feature_reviews:)
    super(release)
    @feature_reviews = feature_reviews
  end

  def approved?
    feature_reviews.any?(&:approved?)
  end

  def approval_status
    return nil if feature_reviews.empty?
    approved? ? :approved : :not_approved
  end
end
