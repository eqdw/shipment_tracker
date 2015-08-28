require 'forwardable'

class ReleaseWithStatus < SimpleDelegator
  extend Forwardable

  def_delegators :@query, :feature_reviews

  attr_reader :time

  def initialize(release:, git_repository:, at: Time.now, query_class: Queries::ReleaseQuery)
    super(release)
    @release = release
    @time = at
    @query = query_class.new(release: release, git_repository: git_repository, at: time)
  end

  def approved?
    feature_reviews.any?(&:approved?)
  end

  def approval_status
    return nil if feature_reviews.empty?
    approved? ? :approved : :unapproved
  end

  private

  attr_reader :query
end
