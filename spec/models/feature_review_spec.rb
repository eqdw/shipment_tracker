require 'spec_helper'
require 'feature_review'

RSpec.describe FeatureReview do
  let(:base_path) { '/feature_reviews' }

  describe '#path' do
    let(:path) { "#{base_path}?uat_url=http://uat.com&apps%5Bapp1%5D=xxx&apps%5Bapp2%5D=yyy" }

    subject { FeatureReview.new(path: path, versions: %w(xxx yyy)).path }

    it { is_expected.to eq('/feature_reviews?uat_url=http://uat.com&apps%5Bapp1%5D=xxx&apps%5Bapp2%5D=yyy') }
  end

  describe '#uat_host' do
    let(:path) { "#{base_path}?uat_url=http://uat.com&apps%5Bapp1%5D=xxx&apps%5Bapp2%5D=yyy" }

    subject { FeatureReview.new(path: path, versions: %w(xxx yyy)).uat_host }

    it { is_expected.to eq('uat.com') }

    context 'when scheme is missing' do
      let(:path) { "#{base_path}?uat_url=uat.com&apps%5Bapp1%5D=xxx&apps%5Bapp2%5D=yyy" }
      it { is_expected.to eq('uat.com') }
    end

    context 'when uat_url is missing' do
      let(:path) { "#{base_path}?apps%5Bapp1%5D=xxx&apps%5Bapp2%5D=yyy" }
      it { is_expected.to be_nil }
    end
  end

  describe '#uat_url' do
    let(:path) { "#{base_path}?uat_url=http://uat.com&apps%5Bapp1%5D=xxx&apps%5Bapp2%5D=yyy" }

    subject { FeatureReview.new(path: path, versions: %w(xxx yyy)).uat_url }

    it { is_expected.to eq('http://uat.com') }

    context 'when scheme is missing' do
      let(:path) { "#{base_path}?uat_url=uat.com&apps%5Bapp1%5D=xxx&apps%5Bapp2%5D=yyy" }
      it { is_expected.to eq('http://uat.com') }
    end

    context 'when uat_url is missing' do
      let(:path) { "#{base_path}?apps%5Bapp1%5D=xxx&apps%5Bapp2%5D=yyy" }
      it { is_expected.to be_nil }
    end
  end

  describe '#app_versions' do
    let(:path) { "#{base_path}?apps%5Bapp1%5D=xxx&apps%5Bapp2%5D=yyy&apps%5Bapp3%5D" }

    subject { FeatureReview.new(path: path, versions: %w(xxx yyy)).app_versions }

    it { is_expected.to eq('app1' => 'xxx', 'app2' => 'yyy') }
  end

  describe '#base_path' do
    let(:path) { '/something?uat_url=http://uat.com&apps%5Bapp1%5D=xxx&apps%5Bapp2%5D=yyy' }

    subject { FeatureReview.new(path: path, versions: %w(xxx yyy)).base_path }

    it { is_expected.to eq('/something') }
  end

  describe '#query_hash' do
    let(:path) { '/something?uat_url=uat.com&apps%5Bapp1%5D=xxx&apps%5Bapp2%5D=yyy' }

    subject { FeatureReview.new(path: path, versions: %w(xxx yyy)).query_hash }

    it {
      is_expected.to eq(
        'apps' => { 'app1' => 'xxx', 'app2' => 'yyy' },
        'uat_url' => 'uat.com',
      )
    }
  end

  describe '#approved?' do
    let(:path) { '/something?apps%5Bapp1%5D=xxx&apps%5Bapp2%5D=yyy&uat_url=http://uat.com' }
    let(:approval_time) { 2.days.ago }

    context 'when approved_at is set' do
      subject { FeatureReview.new(path: path, versions: %w(xxx yyy), approved_at: approval_time).approved? }
      it { is_expected.to eq(true) }
    end

    context 'when approved_at is NOT set' do
      subject { FeatureReview.new(path: path, versions: %w(xxx yyy), approved_at: nil).approved? }
      it { is_expected.to eq(false) }
    end
  end

  context '#approval_status' do
    let(:path) { '/something?apps%5Bapp1%5D=xxx&apps%5Bapp2%5D=yyy&uat_url=http://uat.com' }
    let(:approval_time) { 2.days.ago }

    context 'when approved' do
      subject { FeatureReview.new(path: path, versions: %w(xxx yyy), approved_at: approval_time) }
      it 'returns :approved' do
        expect(subject).to be_approved
        expect(subject.approval_status).to eq(:approved)
      end
    end

    context 'when NOT approved' do
      subject { FeatureReview.new(path: path, versions: %w(xxx yyy), approved_at: nil) }
      it 'returns :not_approved' do
        expect(subject).not_to be_approved
        expect(subject.approval_status).to eq(:not_approved)
      end
    end
  end

  context '#approved_path' do
    let(:path) { '/something?apps%5Bapp1%5D=xxx&apps%5Bapp2%5D=yyy&uat_url=http://uat.com' }
    let(:approval_time) { Time.parse('2013-09-05 14:56:52 UTC') }

    context 'when approved' do
      subject { FeatureReview.new(path: path, versions: %w(xxx yyy), approved_at: approval_time) }
      it 'returns the the path as at the approved_at time' do
        expect(subject).to be_approved
        expect(subject.approved_path).to eq(
          '/something?apps%5Bapp1%5D=xxx&apps%5Bapp2%5D=yyy&'\
          'time=2013-09-05T14%3A56%3A52%2B00%3A00&'\
          'uat_url=http%3A%2F%2Fuat.com',
        )
      end
    end

    context 'when not approved' do
      subject { FeatureReview.new(path: path, versions: %w(xxx yyy), approved_at: nil) }
      it 'returns nil' do
        expect(subject).not_to be_approved
        expect(subject.approved_path).to be_nil
      end
    end
  end
end
