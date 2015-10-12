require 'rails_helper'

RSpec.describe ApplicationHelper do
  describe '#commit_link' do
    let(:version) { 'abcdefghijklmnopqrstuvwxyz' }
    let(:github_repo_url) { 'https://github.com/organization/repo' }

    it 'returns a short-sha link to the commit' do
      link = link_to('abcdefg', "#{github_repo_url}/commit/#{version}", target: '_blank')
      expect(helper.commit_link(version, github_repo_url)).to eq(link)
    end
  end

  describe '#pull_request_link' do
    let(:github_repo_url) { 'https://github.com/organization/repo' }

    context 'when the release is a merge commit' do
      let(:commit_subject) { 'Merge pull request #123 from organization/repo' }

      it 'returns a link to the pull request' do
        link = link_to('pull request #123', "#{github_repo_url}/pull/123", target: '_blank')
        expected = "Merge #{link} from organization/repo"
        expect(helper.pull_request_link(commit_subject, github_repo_url)).to eq(expected)
      end
    end

    context 'when the release is not a merge commit' do
      let(:commit_subject) { 'Move along, nothing to see here' }

      it 'returns the commit subject as plain text' do
        expect(helper.pull_request_link(commit_subject, github_repo_url)).to eq(commit_subject)
      end
    end
  end
end
