require 'queries/release_query'

class ReleaseWithStatus < SimpleDelegator
  def initialize(release:, git_repository:, query_class: Queries::ReleaseQuery)
    super(release)
    @release = release
    @git_repository = git_repository
    @query = query_class.new(release: release, git_repository: git_repository, at: committed_to_master_at)
  end

  delegate :feature_reviews, to: :@query

  def approved?
    feature_reviews.any?(&:approved?)
  end

  def approval_status
    return nil if feature_reviews.empty?
    approved? ? :approved : :unapproved
  end

  def committed_to_master_at
    @committed_to_master_at ||= git_repository.commit_to_master_for(version).try(:time)
  end

  private

  attr_reader :git_repository
end
