require 'rails_helper'
require 'git_repository'
require 'support/git_test_repository'
require 'support/repository_builder'

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
      let(:sha) { commit('A') }
      it { is_expected.to be(true) }
    end

    context 'when commit id does not exist' do
      let(:sha) { '8056d10ec2776f5f2d6fe382560dc20a14fb565d' }
      it { is_expected.to be(false) }
    end

    context 'when commit id is too short (even if it exists)' do
      let(:sha) { commit('A').slice(1..3) }
      it { is_expected.to be(false) }
    end

    context 'when commit id is invalid' do
      let(:sha) { '1NV4LiD' }
      it { is_expected.to be(false) }
    end
  end

  describe '#commits_between' do
    let(:git_diagram) { '-A-B-C-o' }

    it 'returns all commits between two commits' do
      commits = repo.commits_between(commit('A'), commit('C')).map(&:id)

      expect(commits).to contain_exactly(commit('B'), commit('C'))
    end

    context 'when an invalid commit is provided' do
      it 'raises a GitRepository::CommitNotValid exception' do
        invalid_commit = '1NV4LiD'

        expect {
          repo.commits_between(commit('C'), invalid_commit)
        }.to raise_error(GitRepository::CommitNotValid, invalid_commit)
      end
    end

    context 'when a non existent commit is provided' do
      it 'raises a GitRepository::CommitNotValid exception' do
        non_existent_commit = '8120765f3fce2da11a5c8e17d3ca800847912424'

        expect {
          repo.commits_between(commit('C'), non_existent_commit)
        }.to raise_error(GitRepository::CommitNotFound, non_existent_commit)
      end
    end
  end

  describe '#recent_commits' do
    let(:git_diagram) { '-o-A-B-C' }

    it 'returns specified number of recent commits' do
      commits = repo.recent_commits(3).map(&:id)

      expect(commits).to eq([commit('C'), commit('B'), commit('A')])
    end

    describe 'branch selection' do
      let(:git_diagram) { '-A' }

      before do
        allow(rugged_repo).to receive(:branches).and_return(branches)
      end

      subject { repo.recent_commits(3).map(&:id) }

      context 'when there is a remote production branch' do
        let(:branches) {
          {
            'origin/production' => double('branch', target_id: commit('A')),
            'origin/master' => double('branch'),
            'master' => double('branch'),
          }
        }

        it 'returns commits from origin/production' do
          is_expected.to eq([commit('A')])
        end
      end

      context 'when there is a remote master branch, but no remote production' do
        let(:branches) {
          {
            'origin/master' => double('branch', target_id: commit('A')),
            'master' => double('branch'),
          }
        }

        it 'returns commits from origin/master' do
          is_expected.to eq([commit('A')])
        end
      end

      context 'when there are no remote branches called production or master' do
        let(:branches) {
          {
            'origin/other' => double('branch'),
            'master' => double('branch', target_id: commit('A')),
          }
        }

        it 'returns commits from master' do
          is_expected.to eq([commit('A')])
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
        descendant_commits = repo.get_descendant_commits_of_branch(commit('A')).map(&:id)

        expect(descendant_commits).to contain_exactly(commit('B'), commit('C'))
      end
    end

    context 'when given commit on master' do
      let(:git_diagram) { '-o-A-o' }

      it 'returns empty' do
        expect(repo.get_descendant_commits_of_branch(commit('A'))).to be_empty
      end

      context 'and it is the initial commit' do
        let(:git_diagram) { '-A-o' }

        it 'returns empty' do
          expect(repo.get_descendant_commits_of_branch(commit('A'))).to be_empty
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
        expect(repo.get_descendant_commits_of_branch(commit('A'))).to be_empty
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
      let(:sha) { commit('C') }
      it { is_expected.to be(true) }
    end

    context 'when on a non merge commit' do
      let(:sha) { commit('B') }
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
        let(:sha) { commit('C') }
        it { is_expected.to eq(commit('B')) }
      end

      context 'branch_parent was committed AFTER parent on master' do
        let(:git_diagram) do
          <<-'EOS'
          o-A----B
         /        \
        -o-----o----C---o
          EOS
        end

        let(:sha) { commit('C') }
        it { is_expected.to eq(commit('B')) }
      end
    end

    context 'when on a non merge commit' do
      let(:sha) { commit('B') }
      it { is_expected.to eq(commit('A')) }
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

    let(:sha) { commit('C') }
    it 'returns the ancestors of a commit up to the merge base' do
      is_expected.to contain_exactly(commit('B'), commit('A'))
    end

    context 'when the commit is the parent of a merge commit' do
      let(:git_diagram) do
        <<-'EOS'
             A-B
            /   \
          -o--o--C
        EOS
      end

      let(:sha) { commit('B') }
      it 'includes the merge commit in the result' do
        is_expected.to contain_exactly(commit('A'), commit('C'))
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

      let(:sha) { commit('C') }
      it 'returns the feature branch ancestors of the merge commit but not the merge commit itself' do
        is_expected.to contain_exactly(commit('A'), commit('B'))
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
  end

  describe '#path' do
    it 'returns the rugged repository path' do
      expect(repo.path).to eq(rugged_repo.path)
    end
  end

  private

  def commit(version)
    test_git_repo.commit_for_pretend_version(version)
  end
end
