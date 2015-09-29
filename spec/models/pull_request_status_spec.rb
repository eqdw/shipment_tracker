require 'rails_helper'
require 'pull_request_status'
require 'feature_review_with_statuses'

RSpec.describe PullRequestStatus do
  let(:token) { 'a-token' }
  let(:routes) { double(:routes) }

  subject(:pull_request_status) {
    described_class.new(
      routes: routes,
      token: token,
    )
  }
  let(:feature_review_repository) { instance_double(Repositories::FeatureReviewRepository) }
  let(:sha) { 'abc123' }
  let(:repo_url) { 'ssh://github.com/some/app_name' }
  let(:expected_url) { 'https://api.github.com/repos/some/app_name/statuses/abc123' }

  let(:expected_headers) {
    {
      'Accept' => 'application/vnd.github.v3+json',
      'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
      'Authorization' => 'token a-token',
      'Content-Type' => 'application/json',
      'User-Agent' => 'Octokit Ruby Gem 4.1.0',
    }
  }

  before do
    allow(Repositories::FeatureReviewRepository).to receive(:new).and_return(feature_review_repository)
    allow(feature_review_repository).to receive(:feature_reviews_for_versions).and_return([])
  end

  describe '#update' do
    context 'when a single feature reviews exists' do
      let(:feature_review) { instance_double(FeatureReview, approved?: true, path: '/some-path?app=1') }
      let(:root_url) { 'https://shipment-tracker.co.uk/' }

      before do
        allow(routes).to receive(:root_url).and_return(root_url)
        allow(feature_review_repository)
          .to receive(:feature_reviews_for_versions).with([sha]).and_return([feature_review])
      end

      it 'posts status "success" with description and link to feature review' do
        expected_body = {
          context: 'shipment-tracker',
          target_url: 'https://shipment-tracker.co.uk/some-path?app=1',
          description: 'There are approved feature reviews for this commit',
          state: 'success',
        }
        stub = stub_request(:post, expected_url).with(body: expected_body, headers: expected_headers)

        pull_request_status.update(repo_url: repo_url, sha: sha)
        expect(stub).to have_been_requested
      end
    end

    context 'when multiple feature reviews exist' do
      let(:review1) { instance_double(FeatureReview, approved?: true, path: '/some-path?app=1') }
      let(:review2) { instance_double(FeatureReview, approved?: true, path: '/some-path?app=1') }
      let(:search_url) { 'https://shipment-tracker.co.uk/search' }

      before do
        allow(feature_review_repository)
          .to receive(:feature_reviews_for_versions).with([sha]).and_return([review1, review2])
        allow(routes)
          .to receive(:search_feature_reviews_url)
          .with(protocol: 'https', application: 'app_name', versions: sha)
          .and_return(search_url)
      end

      it 'posts status "success" with description and link to feature review' do
        expected_body = {
          context: 'shipment-tracker',
          target_url: search_url,
          description: 'There are approved feature reviews for this commit',
          state: 'success',
        }
        stub = stub_request(:post, expected_url).with(body: expected_body)

        pull_request_status.update(repo_url: repo_url, sha: sha)
        expect(stub).to have_been_requested
      end
    end

    context 'when no feature review exists' do
      let(:new_feature_review_url) { 'https://shipment-tracker.co.uk/new' }

      before do
        allow(feature_review_repository).to receive(:feature_reviews_for_versions).with([sha]).and_return([])
        allow(routes).to receive(:new_feature_reviews_url).and_return(new_feature_review_url)
      end

      it 'passes the results of #status_for and #target_url_for to #publish_status' do
        expected_body = {
          context: 'shipment-tracker',
          target_url: new_feature_review_url,
          description: 'There are no feature reviews for this commit',
          state: 'failure',
        }
        stub = stub_request(:post, expected_url).with(body: expected_body)

        pull_request_status.update(repo_url: repo_url, sha: sha)
        expect(stub).to have_been_requested
      end
    end
  end

  describe '#reset' do
    it 'sends a POST request to api.github.com with the correct path' do
      expected_body = {
        context: 'shipment-tracker',
        target_url: nil,
        description: 'Checking for feature reviews',
        state: 'pending',
      }
      stub = stub_request(:post, expected_url).with(body: expected_body)

      pull_request_status.reset(repo_url: repo_url, sha: sha)
      expect(stub).to have_been_requested
    end
  end
end
