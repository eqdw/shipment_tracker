require 'spec_helper'
require 'support/git_test_repository'
require 'support/repository_builder'

require 'git_repository'

require 'rugged'

RSpec.describe GitRepository do
  let(:git_diagram) { '-A' }
  let(:test_git_repo) { Support::RepositoryBuilder.build(git_diagram) }
  let(:rugged_repo) { Rugged::Repository.new(test_git_repo.dir) }
  subject(:repo) { GitRepository.new(rugged_repo) }

  describe '#exists?' do
    let(:git_diagram) { '-A' }

    subject { repo.exists?(sha) }

    context 'when commit id exists' do
      let(:sha) { version('A') }
      it { is_expected.to be(true) }
    end

    context 'when commit id does not exist' do
      let(:sha) { '8056d10ec2776f5f2d6fe382560dc20a14fb565d' }
      it { is_expected.to be(false) }
    end

    context 'when commit id is too short (even if it exists)' do
      let(:sha) { version('A').slice(1..3) }
      it { is_expected.to be(false) }
    end

    context 'when commit id is invalid' do
      let(:sha) { '1NV4LiD COMMIT SHA BUT HAS PROPER LENGTH' }
      it { is_expected.to be(false) }
    end
  end

  describe '#commits_between' do
    let(:git_diagram) { '-A-B-C-o' }

    it 'returns all commits between two commits, including the end commit' do
      commits = repo.commits_between(version('A'), version('C')).map(&:id)

      expect(commits).to eq([version('B'), version('C')])
    end

    it 'returns commit objects with correct author and message' do
      commit = repo.commits_between(version('B'), version('C')).first
      expect(commit).to be_a(GitCommit)
      expect(commit.id).to eq(version('C'))
      expect(commit.author_name).to eq('Charly')
      expect(commit.message).to eq('Change can confuse')
    end

    context 'when an invalid commit is provided' do
      it 'raises a GitRepository::CommitNotValid exception' do
        invalid_commit = '1NV4LiD'

        expect {
          repo.commits_between(version('C'), invalid_commit)
        }.to raise_error(GitRepository::CommitNotValid, invalid_commit)
      end
    end

    context 'when a non existent commit is provided' do
      it 'raises a GitRepository::CommitNotValid exception' do
        non_existent_commit = '8120765f3fce2da11a5c8e17d3ca800847912424'

        expect {
          repo.commits_between(version('C'), non_existent_commit)
        }.to raise_error(GitRepository::CommitNotFound, non_existent_commit)
      end
    end
  end

  describe '#recent_commits_on_main_branch' do
    let(:git_diagram) do
      <<-'EOS'
        B--C----E
       /         \
 -o---A-------D---F---G-
        EOS
    end

    it 'returns specified number of recent commits on the main branch' do
      commits = repo.recent_commits_on_main_branch(4).map(&:id)

      expect(commits).to eq([version('G'), version('F'), version('D'), version('A')])
    end

    it 'returns commit objects with correct 1st and 2nd Parent IDs' do
      commit = repo.recent_commits_on_main_branch(2)[1]
      expect(commit).to be_a(GitCommit)
      expect(commit.id).to eq(version('F'))
      expect(commit.parent_ids[0]).to eq(version('D'))
      expect(commit.parent_ids[1]).to eq(version('E'))
    end

    it 'returns commit objects with correct author and message' do
      commit = repo.recent_commits_on_main_branch(1).first
      expect(commit).to be_a(GitCommit)
      expect(commit.id).to eq(version('G'))
      expect(commit.author_name).to eq('Gregory')
      expect(commit.message).to eq('Good goes green')
    end

    describe 'branch selection' do
      let(:git_diagram) { '-A' }

      before do
        allow(rugged_repo).to receive(:branches).and_return(branches)
      end

      subject { repo.recent_commits_on_main_branch(3).map(&:id) }

      context 'when there is a remote production branch' do
        let(:branches) {
          {
            'origin/production' => double('branch', target_id: version('A')),
            'origin/master' => double('branch'),
            'master' => double('branch'),
          }
        }

        it 'returns commits from origin/production' do
          is_expected.to eq([version('A')])
        end
      end

      context 'when there is a remote master branch, but no remote production' do
        let(:branches) {
          {
            'origin/master' => double('branch', target_id: version('A')),
            'master' => double('branch'),
          }
        }

        it 'returns commits from origin/master' do
          is_expected.to eq([version('A')])
        end
      end

      context 'when there are no remote branches called production or master' do
        let(:branches) {
          {
            'origin/other' => double('branch'),
            'master' => double('branch', target_id: version('A')),
          }
        }

        it 'returns commits from master' do
          is_expected.to eq([version('A')])
        end
      end
    end
  end

  describe '#get_descendant_commits_of_branch' do
    context "when given commit is part of a branch that's merged into master" do
      let(:git_diagram) do
        <<-'EOS'
        o-A-B---
       /        \
     -o-------o--C---o
        EOS
      end

      it 'returns the descendant commits up to and including the merge commit' do
        descendant_commits = repo.get_descendant_commits_of_branch(version('A')).map(&:id)

        expect(descendant_commits).to eq([version('B'), version('C')])
      end

      it 'returns commit objects with correct author and message' do
        commit = repo.get_descendant_commits_of_branch(version('A')).first
        expect(commit).to be_a(GitCommit)
        expect(commit.id).to eq(version('B'))
        expect(commit.author_name).to eq('Berta')
        expect(commit.message).to eq('Built by Berta')
      end
    end

    context 'when given commit is a fork' do
      let(:git_diagram) do
        <<-'EOS'
        B--C----E
       /         \
 -o---A-------D---F---G-
        EOS
      end

      it 'returns empty array' do
        descendant_commits = repo.get_descendant_commits_of_branch(version('A')).map(&:id)

        expect(descendant_commits).to be_empty
      end
    end

    context 'when given commit on master' do
      let(:git_diagram) { '-o-A-o' }

      it 'returns empty' do
        expect(repo.get_descendant_commits_of_branch(version('A'))).to be_empty
      end

      context 'and it is the initial commit' do
        let(:git_diagram) { '-A-o' }

        it 'returns empty' do
          expect(repo.get_descendant_commits_of_branch(version('A'))).to be_empty
        end
      end
    end

    context 'when branch not merged' do
      let(:git_diagram) do
        <<-'EOS'
             o-A-o
            /
          -o-----o
        EOS
      end

      it 'returns the descendant commits up to the tip of the branch' do
        expect(repo.get_descendant_commits_of_branch(version('A'))).to be_empty
      end
    end

    context 'when the sha is invalid' do
      let(:git_diagram) do
        <<-'EOS'
             o-A-o
            /
          -o-----o
        EOS
      end
      it 'returns empty' do
        expect(repo.get_descendant_commits_of_branch('InvalidSha')).to be_empty
      end
    end
  end

  describe '#merge?' do
    let(:git_diagram) do
      <<-'EOS'
      o-A-B---
     /        \
   -o-------o--C---o
      EOS
    end

    subject { repo.merge?(sha) }

    context 'when on a merge commit' do
      let(:sha) { version('C') }
      it { is_expected.to be(true) }
    end

    context 'when on a non merge commit' do
      let(:sha) { version('B') }
      it { is_expected.to be(false) }
    end

    context 'when not a real commit id' do
      let(:sha) { 'asdfbdd!' }
      it { expect { subject }.to raise_error(GitRepository::CommitNotValid, sha) }
    end

    context 'when a non existent commit id' do
      let(:sha) { '5c6e280c6c4f5aff08a179526b6d73410552f453' }
      it { expect { subject }.to raise_error(GitRepository::CommitNotFound, sha) }
    end
  end

  describe '#branch_parent' do
    let(:git_diagram) do
      <<-'EOS'
      o-A-B---
     /        \
   -o-------o--C---o
      EOS
    end

    subject { repo.branch_parent(sha) }

    context 'when on a merge commit' do
      context 'branch_parent was committed BEFORE parent on master' do
        let(:sha) { version('C') }
        it { is_expected.to eq(version('B')) }
      end

      context 'branch_parent was committed AFTER parent on master' do
        let(:git_diagram) do
          <<-'EOS'
          o-A----B
         /        \
        -o-----o----C---o
          EOS
        end

        let(:sha) { version('C') }
        it { is_expected.to eq(version('B')) }
      end
    end

    context 'when on a non merge commit' do
      let(:sha) { version('B') }
      it { is_expected.to eq(version('A')) }
    end

    context 'when not a real commit id' do
      let(:sha) { 'asdfbdd!' }
      it { expect { subject }.to raise_error(GitRepository::CommitNotValid, sha) }
    end

    context 'when a non existent commit id' do
      let(:sha) { '5c6e280c6c4f5aff08a179526b6d73410552f453' }
      it { expect { subject }.to raise_error(GitRepository::CommitNotFound, sha) }
    end
  end

  describe '#get_dependent_commits' do
    let(:git_diagram) do
      <<-'EOS'
           A-B-C-o
          /       \
        -o----o----o
      EOS
    end

    subject { repo.get_dependent_commits(sha).map(&:id) }

    let(:sha) { version('C') }
    it 'returns the ancestors of a commit up to the merge base' do
      is_expected.to contain_exactly(version('B'), version('A'))
    end

    it 'returns commit objects with correct author and message' do
      commit = repo.get_dependent_commits(sha).detect { |c| c.id == version('B') }
      expect(commit).to be_a(GitCommit)
      expect(commit.id).to eq(version('B'))
      expect(commit.author_name).to eq('Berta')
      expect(commit.message).to eq('Built by Berta')
    end

    context 'when the commit is the parent of a merge commit' do
      let(:git_diagram) do
        <<-'EOS'
             A-B
            /   \
          -o--o--C
        EOS
      end

      let(:sha) { version('B') }
      it 'includes the merge commit in the result' do
        is_expected.to contain_exactly(version('A'), version('C'))
      end
    end

    context 'when the commit is a merge commit' do
      let(:git_diagram) do
        <<-'EOS'
             A-B
            /   \
          -o--o--C
        EOS
      end

      let(:sha) { version('C') }
      it 'returns the feature branch ancestors of the merge commit but not the merge commit itself' do
        is_expected.to contain_exactly(version('A'), version('B'))
      end
    end

    context 'when the sha is invalid' do
      let(:git_diagram) do
        <<-'EOS'
             o-A-o
            /
          -o-----o
        EOS
      end
      it 'is empty' do
        expect(repo.get_dependent_commits('InvalidSha')).to be_empty
      end
    end

    context 'when commmit is on master' do
      let(:git_diagram) { '-A-B-C-o' }
      let(:sha) { version('B') }

      it { is_expected.to be_empty }

      context 'when commit is first commit' do
        let(:sha) { version('A') }

        it { is_expected.to be_empty }
      end
    end
  end

  describe '#path' do
    it 'returns the rugged repository path' do
      expect(repo.path).to eq(rugged_repo.path)
    end
  end

  describe '#remote_url' do
    context 'when there are remotes' do
      before do
        rugged_repo.remotes.create('another', 'git://github.com/libgit2/rugged.git')
      end

      it 'returns the url for the "origin" remote' do
        expect(repo.remote_url).to eq(rugged_repo.remotes['origin'].url)
      end
    end

    context 'when there are no remotes' do
      before do
        rugged_repo.remotes.each do |remote|
          rugged_repo.remotes.delete(remote)
        end
      end
      it 'returns nil' do
        expect(repo.remote_url).to eq(nil)
      end
    end
  end

  private

  def version(pretend_version)
    test_git_repo.commit_for_pretend_version(pretend_version)
  end
end
