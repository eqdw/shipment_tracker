require 'rails_helper'

RSpec.describe GithubNotificationsController do
  describe 'POST #create', :logged_in do
    let(:repo_location_uri) { 'ssh://git@github.com/FundingCircle/hello_world_rails.git' }

    context 'when event is a pull request' do
      before do
        request.env['HTTP_X_GITHUB_EVENT'] = 'pull_request'
        GitRepositoryLocation.create(uri: repo_location_uri)
      end

      context 'when the pull request is newly opened' do
        let(:sha) { '12345' }
        let(:repo_url) { 'https://github.com/FundingCircle/hello_world_rails' }
        let(:payload) { github_pr_payload(action: 'opened', repo_url: repo_url, sha: sha) }

        it 'sets the pull request status' do
          request.host = 'foo.bar'

          pull_request_status = instance_double(PullRequestStatus)
          allow(PullRequestStatus).to receive(:new).and_return(pull_request_status)
          expect(pull_request_status).to receive(:reset).with(
            repo_url: repo_url,
            sha: sha,
          ).ordered
          expect(pull_request_status).to receive(:update).with(
            repo_url: repo_url,
            sha: sha,
          ).ordered

          post :create, github_notification: payload
        end
      end

      context 'when the pull request receives a new commit' do
        let(:sha) { '12345' }
        let(:repo_url) { 'https://github.com/FundingCircle/hello_world_rails' }
        let(:payload) { github_pr_payload(action: 'synchronize', repo_url: repo_url, sha: sha) }

        it 'sets the pull request status' do
          request.host = 'foo.bar'

          pull_request_status = instance_double(PullRequestStatus)
          allow(PullRequestStatus).to receive(:new).and_return(pull_request_status)
          expect(pull_request_status).to receive(:reset).with(
            repo_url: repo_url,
            sha: sha,
          ).ordered
          expect(pull_request_status).to receive(:update).with(
            repo_url: repo_url,
            sha: sha,
          ).ordered

          post :create, github_notification: payload
        end
      end

      context 'when the pull request activity is not relevant' do
        let(:sha) { '12345' }
        let(:repo_url) { 'https://github.com/FundingCircle/hello_world_rails' }
        let(:payload) { github_pr_payload(action: 'reopened', repo_url: repo_url, sha: sha) }

        it 'does not set the pull request status' do
          expect(PullRequestStatus).to_not receive(:new)

          post :create, github_notification: payload
        end
      end

      context 'when the pull request is not for an audited repo' do
        let(:repo_location_uri) { 'ssh://git@github.com/FundingCircle/another_repo.git' }
        let(:sha) { '12345' }
        let(:repo_url) { 'https://github.com/FundingCircle/hello_world_rails' }
        let(:payload) { github_pr_payload(action: 'opened', repo_url: repo_url, sha: sha) }

        it 'does not set the pull request status' do
          expect(PullRequestStatus).to_not receive(:new)

          post :create, github_notification: payload
        end
      end
    end

    context 'when event is a push' do
      before do
        request.env['HTTP_X_GITHUB_EVENT'] = 'push'
      end

      let(:payload) { {} }

      it 'updates the corresponding repository location' do
        expect(GitRepositoryLocation).to receive(:update_from_github_notification).with(payload)

        post :create, payload
      end
    end

    context 'when event is not recognized' do
      it 'responds with a 202 Accepted' do
        post :create

        expect(response).to have_http_status(:accepted)
      end
    end
  end
end
