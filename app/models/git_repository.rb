require 'rugged'

class GitRepository
  class CommitNotFound < RuntimeError; end
  class CommitNotValid < RuntimeError; end

  def initialize(repository)
    @repository = repository
  end

  def exists?(full_sha)
    lookup(full_sha).present?
  end

  def commits_between(from, to)
    instrument('commits_between') do
      validate_commit!(from) unless from.nil?
      validate_commit!(to)

      walker = Rugged::Walker.new(repository)
      walker.sorting(Rugged::SORT_TOPO | Rugged::SORT_REVERSE) # optional
      walker.push(to)
      walker.hide(from) if from

      build_commits(walker)
    end
  end

  def recent_commits(count = 50)
    walker = Rugged::Walker.new(repository)
    walker.sorting(Rugged::SORT_TOPO)
    walker.push(main_branch.target_id)

    build_commits(walker.take(count))
  end

  # Returns "dependent commits" given a commit sha from a topic branch.
  # Dependent commits are the merge commit plus any commits between the given
  # commit and the "fork commit" on master (i.e. commit the branch is based
  # off of).
  # We can use Rugged::Repository#merge_base to find the fork commit, but we
  # need to loop until the master commit is not a descendant of the given
  # commit, otherwise the merge base will be the given commit and not the fork
  # commit.
  def get_dependent_commits(commit_oid)
    validate_commit!(commit_oid)
    master = main_branch.target

    dependent_commits = []
    common_ancestor_oid = nil
    loop do
      common_ancestor_oid = repository.merge_base(master.oid, commit_oid)
      break if common_ancestor_oid != commit_oid
      dependent_commits << build_commit(master) if merge_commit_for?(master, commit_oid)
      master = master.parents.first
    end

    dependent_commits + commits_between(common_ancestor_oid, commit_oid)[0...-1]
  rescue CommitNotValid; []
  end

  # Returns all commits that are children of the given commit
  # up to and including the merge commit.
  def get_descendant_commits_of_branch(commit_oid)
    verified_commit_oid = lookup(commit_oid).try(:oid)

    return [] if verified_commit_oid.nil? || commit_on_master?(commit_oid)

    commits = []

    walker = get_walker(main_branch.target_id, verified_commit_oid, false)
    walker.each do |commit|
      commits << commit if repository.descendant_of?(commit.oid, verified_commit_oid)
      break if commit == merge_to_master_commit(verified_commit_oid)
    end

    build_commits(commits)
  end

  def merge?(commit_oid)
    validate_commit!(commit_oid)
    @repository.lookup(commit_oid).parents.count > 1
  end

  # For a merge commit, (which has multiple parents) the first parent
  # is the commit on the branch currently checked out.
  # This method assumes that main branch is currently checked out.
  def branch_parent(commit_oid)
    validate_commit!(commit_oid)
    @repository.lookup(commit_oid).parents.last.oid
  end

  def path
    @repository.path
  end

  private

  attr_reader :repository

  def get_walker(push_commit_oid, hide_commit_oid, simplify = false)
    walker = Rugged::Walker.new(repository)
    walker.sorting(Rugged::SORT_TOPO | Rugged::SORT_REVERSE)
    walker.simplify_first_parent if simplify
    walker.push(push_commit_oid)
    walker.hide(hide_commit_oid)
    walker
  end

  def merge_to_master_commit(commit_oid)
    walker = get_walker(main_branch.target_id, commit_oid, true)
    walker.find { |commit| repository.descendant_of?(commit.oid, commit_oid) }
  end

  def commit_on_master?(commit_oid)
    parent_commit = repository.lookup(commit_oid).parents.first
    return true unless parent_commit

    walker = get_walker(main_branch.target_id, parent_commit.oid, true)
    walker.first.oid == commit_oid
  end

  def merge_commit_for?(merge_commit, commit_oid)
    merge_commit.parent_ids.second == commit_oid
  end

  def build_commit(commit)
    GitCommit.new(
      id: commit.oid,
      author_name: commit.author[:name],
      message: commit.message,
      time: commit.time)
  end

  def build_commits(commits)
    commits.map { |c| build_commit(c) }
  end

  def validate_commit!(commit_oid)
    fail CommitNotFound, commit_oid unless repository.exists?(commit_oid)
  rescue Rugged::InvalidError
    raise CommitNotValid, commit_oid
  end

  def instrument(name, &block)
    ActiveSupport::Notifications.instrument(
      "#{name}.git_repository",
      &block)
  end

  def main_branch
    repository.branches['origin/production'] ||
      repository.branches['origin/master'] ||
      repository.branches['master']
  end

  def lookup(sha)
    repository.lookup(sha)
  rescue Rugged::InvalidError, Rugged::ObjectError, Rugged::OdbError
    nil
  end
end
