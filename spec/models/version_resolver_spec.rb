require 'spec_helper'
require 'support/git_test_repository'
require 'support/repository_builder'

require 'git_repository'
require 'version_resolver'

RSpec.describe VersionResolver do
  let(:test_git_repo) { Support::RepositoryBuilder.build(git_diagram) }
  let(:rugged_repo) { Rugged::Repository.new(test_git_repo.dir) }
  let(:git_repository) { GitRepository.new(rugged_repo) }

  describe '#related_versions(version)' do
    let(:git_diagram) do
      <<-'EOS'
           A-B
          /   \
        -o-----C---D
      EOS
    end

    subject(:resolver) { VersionResolver.new(git_repository) }

    it 'resolves the correct versions' do
      aggregate_failures do
        expect(resolver.related_versions(commit('A'))).to match_array(commits('A', 'B', 'C'))
        expect(resolver.related_versions(commit('B'))).to match_array(commits('B', 'C'))
        expect(resolver.related_versions(commit('C'))).to match_array(commits('B', 'C'))
        expect(resolver.related_versions(commit('D'))).to match_array(commits('D'))
      end
    end
  end

  private

  def commit(version)
    test_git_repo.commit_for_pretend_version(version)
  end

  def commits(*versions)
    versions.map { |v| commit(v) }
  end
end
