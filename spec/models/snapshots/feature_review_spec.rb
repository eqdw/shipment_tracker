require 'rails_helper'
require 'snapshots/feature_review'

RSpec.describe Snapshots::FeatureReview do
  describe '.most_recent_snapshot' do
    let!(:feature_reviews) {
      [
        Snapshots::FeatureReview.create(path: '/1', versions: ['first']),
        Snapshots::FeatureReview.create(path: '/2', versions: ['second']),
        Snapshots::FeatureReview.create(path: '/1', versions: ['fourth']),
        Snapshots::FeatureReview.create(path: '/3', versions: ['third']),
      ]
    }

    context 'when path is specified' do
      it 'returns the last snapshot with that path' do
        expect(Snapshots::FeatureReview.most_recent_snapshot('/1')).to eq(feature_reviews[2])
      end
    end

    context 'when path is not specified' do
      it 'returns the last snapshot' do
        expect(Snapshots::FeatureReview.most_recent_snapshot).to eq(feature_reviews.last)
      end
    end
  end
end
