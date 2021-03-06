require 'rails_helper'

RSpec.describe PullRequestStatus do
  subject(:pull_request_status) { described_class.new(token: token) }

  let(:token) { 'a-token' }
  let(:routes) { double(:routes) }

  let(:sha) { 'abc' }
  let(:repo_url) { 'ssh://github.com/some/app_name' }

  let(:expected_url) { 'https://api.github.com/repos/some/app_name/statuses/abc' }
  let(:expected_headers) {
    {
      'Accept' => 'application/vnd.github.v3+json',
      'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
      'Authorization' => 'token a-token',
      'Content-Type' => 'application/json',
      'User-Agent' => /^Octokit Ruby Gem/,
    }
  }
  let(:expected_body) {
    {
      context: 'shipment-tracker',
      target_url: target_url,
      description: description,
      state: state,
    }
  }

  let!(:stub) { stub_request(:post, expected_url).with(body: expected_body, headers: expected_headers) }

  describe '#update' do
    let(:ticket_repository) { instance_double(Repositories::TicketRepository) }

    before do
      allow(Repositories::TicketRepository).to receive(:new).and_return(ticket_repository)
      allow(ticket_repository).to receive(:tickets_for_versions).and_return(tickets)
    end

    context 'when a single feature review exists for the relevant commit' do
      let(:tickets) {
        [
          Ticket.new(
            versions: %w(abc def unrelated),
            paths: [
              feature_review_path(app1: 'abc', app2: 'def'),
              feature_review_path(app1: 'unrelated'),
            ],
            status: 'Done',
          ),
        ]
      }

      let(:target_url) { 'https://localhost/feature_reviews?apps%5Bapp1%5D=abc&apps%5Bapp2%5D=def' }
      let(:description) { 'Approved Feature Review found' }
      let(:state) { 'success' }

      it 'posts status "success" with description and link to feature review' do
        pull_request_status.update(repo_url: repo_url, sha: sha)
        expect(stub).to have_been_requested
      end
    end

    context 'when multiple feature reviews exist for the relevant commit' do
      context 'when one of the feature reviews are approved' do
        let(:tickets) {
          [
            Ticket.new(
              versions: %w(abc def),
              paths: [feature_review_path(app1: 'abc', app2: 'def')],
              status: 'In Progress',
            ),
            Ticket.new(
              versions: %w(abc def),
              paths: [feature_review_path(app1: 'abc')],
              status: 'Done',
            ),
          ]
        }

        let(:target_url) { 'https://localhost/feature_reviews/search?application=app_name&version=abc' }
        let(:description) { 'Approved Feature Review found' }
        let(:state) { 'success' }

        it 'posts status "success" with description and to feature review search' do
          pull_request_status.update(repo_url: repo_url, sha: sha)
          expect(stub).to have_been_requested
        end
      end

      context 'when no feature reviews are approved' do
        let(:tickets) {
          [
            Ticket.new(
              versions: %w(abc def),
              paths: [feature_review_path(app1: 'abc', app2: 'def')],
              status: 'In Progress',
            ),
            Ticket.new(
              versions: %w(abc def),
              paths: [feature_review_path(app1: 'abc')],
              status: 'In Progress',
            ),
          ]
        }

        let(:target_url) { 'https://localhost/feature_reviews/search?application=app_name&version=abc' }
        let(:description) { 'Awaiting approval for Feature Review' }
        let(:state) { 'pending' }

        it 'posts status "pending" with description and link to feature review search' do
          pull_request_status.update(repo_url: repo_url, sha: sha)
          expect(stub).to have_been_requested
        end
      end
    end

    context 'when no feature review exists' do
      let(:deploy_repository) { instance_double(Repositories::DeployRepository) }
      let(:deploy) { nil }
      let(:tickets) { [] }
      let(:target_url) { 'https://localhost/feature_reviews?apps%5Bapp_name%5D=abc' }
      let(:description) { "No Feature Review found. Click 'Details' to create one." }
      let(:state) { 'failure' }

      before do
        allow(Repositories::DeployRepository).to receive(:new).and_return(deploy_repository)
        allow(deploy_repository).to receive(:last_staging_deploy_for_version).with(sha).and_return(deploy)
      end

      it 'posts status "failure" with description and link to view a feature review' do
        pull_request_status.update(repo_url: repo_url, sha: sha)
        expect(stub).to have_been_requested
      end

      context 'when there are deploys for the app version under review' do
        context 'when the deploy is a staging deploy' do
          let(:deploy) { instance_double(Deploy, server: 'uat.com') }
          let(:target_url) { 'https://localhost/feature_reviews?apps%5Bapp_name%5D=abc&uat_url=uat.com' }

          it 'includes the UAT URL in the link' do
            pull_request_status.update(repo_url: repo_url, sha: sha)
            expect(stub).to have_been_requested
          end
        end

        context 'when the deploy is a production deploy' do
          let(:deploy) { nil }

          it 'does not include the UAT URL in the link' do
            pull_request_status.update(repo_url: repo_url, sha: sha)
            expect(stub).to have_been_requested
          end
        end
      end
    end
  end

  describe '#reset' do
    let(:target_url) { nil }
    let(:description) { 'Searching for Feature Review' }
    let(:state) { 'pending' }

    it 'posts status "pending" with description and no link' do
      pull_request_status.reset(repo_url: repo_url, sha: sha)
      expect(stub).to have_been_requested
    end
  end
end
