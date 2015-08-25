require 'spec_helper'
require 'pull_request_status'
require 'feature_review_with_statuses'

RSpec.describe PullRequestStatus do
  let(:token) { 'a-token' }
  let(:routes) { double }
  subject(:pull_request_status) {
    described_class.new(
      routes: routes,
      token: token,
    )
  }

  describe '#update' do
    it 'passes the results of #status_for and #target_url_for to #publish_status' do
      feature_review = instance_double(FeatureReview)

      allow(pull_request_status).to receive(:feature_reviews).with(['12345']).and_return([feature_review])
      allow(pull_request_status).to receive(:status_for).with([feature_review]).and_return(
        status: 'great',
        description: 'stuff')
      allow(pull_request_status).to receive(:target_url_for).with(
        repo_url: 'ssh://github.com/some/thing',
        sha: '12345',
        feature_reviews: [feature_review],
      ).and_return('http://foo.bar')

      expect(pull_request_status).to receive(:publish_status).with(
        repo_url: 'ssh://github.com/some/thing',
        sha: '12345',
        status: 'great',
        description: 'stuff',
        target_url: 'http://foo.bar',
      )

      pull_request_status.update(
        repo_url: 'ssh://github.com/some/thing',
        sha: '12345',
      )
    end
  end

  describe '#reset' do
    it 'sets the status to pending' do
      expect(pull_request_status).to receive(:publish_status).with(
        repo_url: 'ssh://github.com/a/repo',
        sha: 'xyz',
        status: 'pending',
        description: 'Checking for feature reviews',
      )

      pull_request_status.reset(repo_url: 'ssh://github.com/a/repo', sha: 'xyz')
    end
  end

  describe '#publish_status' do
    let(:repo_url) { 'https://github.com/owner/repo' }
    let(:sha) { 'sha' }

    it 'sends a POST request to api.github.com with the correct path' do
      stub = stub_request(:post, 'https://api.github.com/repos/owner/repo/statuses/sha')
      pull_request_status.publish_status(
        repo_url: 'https://github.com/owner/repo',
        sha: 'sha',
        status: 'status',
        description: 'description',
        target_url: 'http://foo.bar',
      )
      expect(stub).to have_been_requested
    end

    it 'sends the json-encoded params in the request body' do
      stub = stub_request(:any, %r{api.github.com/*}).with(
        body: JSON(
          'context' => 'shipment-tracker',
          'target_url' => 'http://foo.bar',
          'description' => 'a-description',
          'state' => 'a-status',
        ),
      )
      pull_request_status.publish_status(
        repo_url: 'https://github.com/owner/repo',
        sha: 'sha',
        status: 'a-status',
        description: 'a-description',
        target_url: 'http://foo.bar',
      )
      expect(stub).to have_been_requested
    end
  end

  describe '#target_url_for' do
    context 'when there are no feature reviews' do
      let(:feature_reviews) {
        []
      }

      it 'is the new feature review url' do
        allow(routes).to receive(:new_feature_reviews_url).with(
          protocol: 'https',
        ).and_return('https://fundingcircle.com/new-feature-reviews')

        expect(pull_request_status.target_url_for(
                 repo_url: 'https://github.com/FundingCircle/app',
                 sha: 'sha',
                 feature_reviews: feature_reviews,
        )).to eq('https://fundingcircle.com/new-feature-reviews')
      end
    end

    context 'when there is one feature review' do
      let(:feature_reviews) {
        [instance_double(FeatureReview, path: '/any-path')]
      }

      it 'is the url for the feature review' do
        allow(routes).to receive(:root_url).with(
          protocol: 'https',
        ).and_return('https://fundingcircle.com/')

        expect(pull_request_status.target_url_for(
                 repo_url: 'https://github.com/FundingCircle/app',
                 sha: 'sha',
                 feature_reviews: feature_reviews,
        )).to eq('https://fundingcircle.com/any-path')
      end
    end

    context 'when there is more than one feature review' do
      let(:feature_reviews) {
        [
          instance_double(FeatureReview, path: '/foo/bar'),
          instance_double(FeatureReview, path: '/baz/qux'),
        ]
      }

      it 'is the search url when there is more than one feature review' do
        allow(routes).to receive(:search_feature_reviews_url).with(
          protocol: 'https',
          application: 'my-app',
          versions: 'a-really-long-sha',
        ).and_return('https://fundingcircle.com/search-url')
        expect(pull_request_status.target_url_for(
                 repo_url: 'https://github.com/FundingCircle/my-app',
                 sha: 'a-really-long-sha',
                 feature_reviews: feature_reviews,
        )).to eq('https://fundingcircle.com/search-url')
      end
    end
  end

  describe '#status_for' do
    it 'is success if some feature reviews are approved and others are not' do
      approved = instance_double(FeatureReviewWithStatuses, approved?: true)
      unapproved = instance_double(FeatureReviewWithStatuses, approved?: false)
      expect(pull_request_status.status_for([approved, unapproved])).to eq(
        status: 'success',
        description: 'There are approved feature reviews for this commit',
      )
    end

    it 'is success if all of the feature reviews are approved' do
      feature_review = instance_double(FeatureReviewWithStatuses, approved?: true)
      expect(pull_request_status.status_for([feature_review])).to eq(
        status: 'success',
        description: 'There are approved feature reviews for this commit',
      )
    end

    it 'is failure if all of the feature reviews are not approved' do
      feature_review = instance_double(FeatureReviewWithStatuses, approved?: false)
      expect(pull_request_status.status_for([feature_review])).to eq(
        status: 'failure',
        description: 'No feature reviews for this commit have been approved',
      )
    end

    it 'is failure if no feature reviews are specified' do
      expect(pull_request_status.status_for([])).to eq(
        status: 'failure',
        description: 'There are no feature reviews for this commit',
      )
    end
  end
end
