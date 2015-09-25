require 'rails_helper'

RSpec.describe ReleaseWithStatus do
  let(:feature_review1) { instance_double(FeatureReview) }

  let(:feature_review2) { instance_double(FeatureReview) }

  let(:feature_reviews) { [feature_review1, feature_review2] }

  let(:release) {
    instance_double(Release,
      version: 'commitsha1',
      production_deploy_time: 3.days.ago,
      subject: 'really important')
  }

  subject(:decorator) {
    ReleaseWithStatus.new(
      release: release,
      feature_reviews: feature_reviews)
  }

  it 'delegates unknown messages to the release' do
    expect(decorator.version).to eq(release.version)
    expect(decorator.production_deploy_time).to eq(release.production_deploy_time)
    expect(decorator.subject).to eq(release.subject)
  end

  describe '#approved?' do
    it 'returns true if any of its feature reviews are approved' do
      allow(feature_review1).to receive(:approved?).and_return(true)
      allow(feature_review2).to receive(:approved?).and_return(false)
      expect(decorator.approved?).to be true
    end

    it 'returns false if none of its feature reviews are approved' do
      allow(feature_review1).to receive(:approved?).and_return(false)
      allow(feature_review2).to receive(:approved?).and_return(false)
      expect(decorator.approved?).to eq(false)
    end
  end

  describe '#approval_status' do
    context 'when release has NO feature review(s)' do
      let(:feature_reviews) { [] }
      it 'returns blank when the release has no features' do
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
        expect(decorator.approval_status).to eq(:not_approved)
      end
    end
  end
end
