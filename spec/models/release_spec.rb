require 'rails_helper'

RSpec.describe Release do
  let(:commit) { GitCommit.new(id: 'abc') }
  let(:feature_review1) { instance_double(FeatureReview) }
  let(:feature_review2) { instance_double(FeatureReview) }
  let(:feature_reviews) { [feature_review1, feature_review2] }

  subject(:release) { described_class.new(commit: commit) }

  describe '#version' do
    it 'returns the commit id' do
      expect(release.version).to eq('abc')
    end
  end

  describe '#approved?' do
    subject(:release) { Release.new(feature_reviews: feature_reviews) }

    it 'returns true if any of its feature reviews are approved' do
      allow(feature_review1).to receive(:approved?).and_return(true)
      allow(feature_review2).to receive(:approved?).and_return(false)
      expect(release.approved?).to be true
    end

    it 'returns false if none of its feature reviews are approved' do
      allow(feature_review1).to receive(:approved?).and_return(false)
      allow(feature_review2).to receive(:approved?).and_return(false)
      expect(release.approved?).to eq(false)
    end
  end

  describe '#approval_status' do
    context 'when release has NO feature review(s)' do
      it 'returns blank when the release has no features' do
        expect(release.approval_status).to be_nil
      end
    end

    context 'when release has feature review(s)' do
      subject(:release) { Release.new(feature_reviews: feature_reviews) }

      it 'returns "approved" when the release is :approved' do
        allow(release).to receive(:approved?).and_return(true)
        expect(release.approval_status).to eq(:approved)
      end

      it 'returns "unapproved" when the release is NOT :approved?' do
        allow(release).to receive(:approved?).and_return(false)
        expect(release.approval_status).to eq(:not_approved)
      end
    end
  end
end
