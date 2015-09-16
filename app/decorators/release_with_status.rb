require 'queries/release_query'

class ReleaseWithStatus < SimpleDelegator
  def initialize(release:, git_repository:, query_class: Queries::ReleaseQuery)
    super(release)
    @release = release
    @git_repository = git_repository
    @query = query_class.new(release: release, git_repository: git_repository)
  end

  delegate :feature_reviews, to: :@query

  def approved?
    feature_reviews.any?(&:approved?)
  end

  def approval_status
    return nil if feature_reviews.empty?
    approved? ? :approved : :unapproved
  end

  private

  attr_reader :git_repository

  def commit_to_master
    git_repository.commit_to_master_for(version)
  end
end
