require 'rails_helper'

RSpec.describe GitRepositoryLocation do
  describe 'before validations' do
    it 'converts SSH clone URIs to SSH URIs' do
      location = GitRepositoryLocation.create(name: 'repo', uri: 'git@github.com:user/repo.git')
      expect(location.uri).to eq('ssh://git@github.com/user/repo.git')
    end

    it 'returns the original URI if it can not convert it' do
      incorrect_uri = 'git@github.com/user/repo.git'
      location = GitRepositoryLocation.create(name: 'repo', uri: incorrect_uri)
      expect(location.uri).to eq(incorrect_uri)
    end
  end

  describe 'validations' do
    it 'must have a valid uri' do
      ssh_url = GitRepositoryLocation.new(name: 'repo', uri: 'ssh://git@github.com/user/repo.git')
      https_url = GitRepositoryLocation.new(name: 'repo', uri: 'https://github.com/FundingCircle/shipment_tracker.git')
      ssh_clone_url = GitRepositoryLocation.new(name: 'repo', uri: 'git@github.com:user/repo.git')
      invalid_url = GitRepositoryLocation.new(name: 'repo', uri: 'github.com\user\repo.git')

      expect(ssh_url).to be_valid
      expect(https_url).to be_valid
      expect(ssh_clone_url).to be_valid
      expect(invalid_url).not_to be_valid
    end
  end

  describe '.uris' do
    let(:uris) { %w(ssh://git@github.com/some/some-repo.git ssh://git@github.com/some/some-repo.git) }
    it 'returns an array of uris' do
      uris.each do |uri|
        GitRepositoryLocation.create(uri: uri)
      end

      expect(GitRepositoryLocation.uris).to match_array(uris)
    end
  end

  describe '.github_url_for_app' do
    let(:app_name) { 'repo' }
    let(:url) { 'https://github.com/organization/repo' }

    context 'when a repository location exists with the app name' do
      before do
        GitRepositoryLocation.create(name: 'repo', uri: uri)
      end

      [
        'ssh://git@github.com/organization/repo.git',
        'git://git@github.com/organization/repo.git',
        'https://github.com/organization/repo.git',
      ].each do |uri|
        context "when the uri is #{uri}" do
          let(:uri) { uri }

          it 'returns a URL to the GitHub repository' do
            github_repo_url = GitRepositoryLocation.github_url_for_app(app_name)
            expect(github_repo_url).to eq(url)
          end
        end
      end
    end

    context 'when no repository locations exists with the app name' do
      it 'returns nil' do
        expect(GitRepositoryLocation.github_url_for_app(app_name)).to be nil
      end
    end
  end

  describe '.github_urls_for_apps' do
    context 'when given a list of app names' do
      let(:app_names) { %w(app1 app2 app3) }

      before do
        app_names.first(2).each do |app_name|
          GitRepositoryLocation.create(name: app_name, uri: "https://github.com/organization/#{app_name}")
        end
      end

      it 'returns a hash of app names and urls' do
        expect(GitRepositoryLocation.github_urls_for_apps(app_names)).to eq(
          'app1' => 'https://github.com/organization/app1',
          'app2' => 'https://github.com/organization/app2',
          'app3' => nil,
        )
      end
    end

    context 'when not given any app names' do
      it 'returns an empty hash' do
        expect(GitRepositoryLocation.github_urls_for_apps([])).to eq({})
      end
    end
  end

  describe '.update_from_github_notification' do
    let(:github_payload) {
      JSON.parse(<<-END)
        {
          "before": "abc123",
          "after": "def456",
          "repository": {
            "name": "repo",
            "full_name": "some/repo",
            "git_url": "git://github.com/some/repo.git",
            "ssh_url": "git@github.com:some/repo.git",
            "clone_url": "https://github.com/some/repo.git"
          }
        }
      END
    }

    before do
      GitRepositoryLocation.create(name: 'some_other_repo', uri: 'ssh://git@github.com/some/other-repo.git')
    end

    context 'when the GitRepositoryLocation has a regular URI' do
      before do
        GitRepositoryLocation.create(name: 'some_repo', uri: 'ssh://git@github.com/some/repo.git')
      end

      it 'updates remote_head for the correct GitRepositoryLocation' do
        GitRepositoryLocation.update_from_github_notification(github_payload)

        expect(GitRepositoryLocation.find_by_name('some_repo').remote_head).to eq('def456')
        expect(GitRepositoryLocation.find_by_name('some_other_repo').remote_head).to be(nil)
      end
    end

    context 'when no GitRepositoryLocation is found' do
      it 'fails silently' do
        expect { GitRepositoryLocation.update_from_github_notification(github_payload) }.to_not raise_error
      end
    end

    context 'when payload does not have a repository key' do
      let(:github_payload) {
        JSON.parse(<<-END)
          {
            "before": "abc123",
            "after": "def456"
          }
        END
      }
      it 'fails silently' do
        expect { GitRepositoryLocation.update_from_github_notification(github_payload) }.to_not raise_error
      end
    end
  end
end
