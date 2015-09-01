require 'queries/release_query'

class ReleaseWithStatus < SimpleDelegator
  attr_reader :time

  def initialize(release:, git_repository:, at: Time.now, query_class: Queries::ReleaseQuery)
    super(release)
    @time = at
    @query = query_class.new(release: release, git_repository: git_repository, at: time)
  end

  delegate :feature_reviews, to: :@query

  def approved?
    feature_reviews.any?(&:approved?)
  end

  def approval_status
    return nil if feature_reviews.empty?
    approved? ? :approved : :unapproved
  end
end
