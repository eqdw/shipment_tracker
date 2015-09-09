require 'rails_helper'

RSpec.describe ReleaseWithStatus do
  let(:query_time) { 1.day.ago }
  let(:time_now) { Time.now }

  let(:feature_review1) {
    instance_double(
      FeatureReview,
      url: feature_review_url(frontend: 'abc', backend: 'xyx'),
      versions: %w(commitsha1))
  }

  let(:feature_review2) {
    instance_double(
      FeatureReview,
      url: feature_review_url(frontend: 'def', backend: 'uvw'),
      versions: %w(commitsha1 commitsha2))
  }

  let(:feature_review_query) { instance_double(Queries::FeatureReviewQuery) }

  let(:release) {
    instance_double(Release,
      version: 'commitsha1',
      production_deploy_time: 3.days.ago,
      subject: 'really important')
  }

  let(:release_query) {
    instance_double(Queries::ReleaseQuery,
      feature_reviews: [feature_review1, feature_review2],
      time: query_time)
  }

  let(:query_class) { class_double(Queries::ReleaseQuery, new: release_query) }

  let(:git_repository) { instance_double(GitRepository) }

  subject(:decorator) {
    ReleaseWithStatus.new(
      release: release,
      git_repository: git_repository,
      query_class: query_class)
  }

  before :each do
    allow(git_repository).to receive(:commit_to_master_for)
      .with('commitsha1')
      .and_return(nil)
  end

  it 'delegates unknown messages to the release' do
    expect(decorator.version).to eq(release.version)
    expect(decorator.production_deploy_time).to eq(release.production_deploy_time)
    expect(decorator.subject).to eq(release.subject)
  end

  it 'delegates :feature_reviews to the query' do
    allow(release_query).to receive(:feature_reviews).and_return([
      instance_double(FeatureReviewWithStatuses),
      instance_double(FeatureReviewWithStatuses),
    ])
    expect(decorator.feature_reviews).to eq(release_query.feature_reviews)
  end

  describe '#committed_to_master_at' do
    let(:merge_time) { 1.day.ago }
    let(:commit) { instance_double(GitCommit, time: release.time) }

    before do
      allow(git_repository).to receive(:commit_to_master_for)
        .with('commitsha1')
        .and_return(commit)
    end

    context 'when the commit is on master' do
      let(:commit) { instance_double(GitCommit, time: time_now) }

      it 'returns the commit time' do
        expect(decorator.committed_to_master_at).to eq(time_now)
      end
    end

    context 'when the commit is a feature branch commit' do
      context 'when feature branch has been merged to master' do
        let(:commit) { instance_double(GitCommit, time: merge_time) }

        it 'returns the commit time of the subsequent merge commit' do
          expect(decorator.committed_to_master_at).to eq(merge_time)
        end
      end

      context 'when feature branch has NOT been merged to master' do
        let(:commit) { nil }

        it 'returns nil' do
          expect(decorator.committed_to_master_at).to eq(nil)
        end
      end
    end
  end

  describe '#approved?' do
    it 'returns true if any of its feature reviews are approved' do
      allow(release_query).to receive(:feature_reviews).and_return([
        instance_double(FeatureReviewWithStatuses, approved?: true),
        instance_double(FeatureReviewWithStatuses, approved?: false),
      ])
      expect(decorator.approved?).to be true
    end

    it 'returns false if none of its feature reviews are approved' do
      allow(release_query).to receive(:feature_reviews).and_return([
        instance_double(FeatureReviewWithStatuses, approved?: false),
        instance_double(FeatureReviewWithStatuses, approved?: false),
      ])
      expect(decorator.approved?).to eq(false)
    end
  end

  describe '#approval_status' do
    context 'when release has NO feature review(s)' do
      it 'returns blank when the release has no features' do
        allow(release_query).to receive(:feature_reviews).and_return([])
        expect(decorator.approval_status).to be_nil
      end
    end

    context 'when release has feature review(s)' do
      it 'returns "approved" when the release is :approved' do
        allow(decorator).to receive(:approved?).and_return(true)
        expect(decorator.approval_status).to eq(:approved)
      end

      it 'returns "unapproved" when the release is NOT :approved?' do
        allow(decorator).to receive(:approved?).and_return(false)
        expect(decorator.approval_status).to eq(:unapproved)
      end
    end
  end
end
