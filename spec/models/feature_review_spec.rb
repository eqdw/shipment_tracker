require 'spec_helper'
require 'feature_review'

RSpec.describe FeatureReview do
  let(:base_url) { 'http://localhost/feature_reviews' }

  describe '#path' do
    let(:url) { "#{base_url}?uat_url=http://uat.com&apps%5Bapp1%5D=xxx&apps%5Bapp2%5D=yyy" }

    subject { FeatureReview.new(url: url, versions: %w(xxx yyy)).path }

    it { is_expected.to eq('/feature_reviews?uat_url=http://uat.com&apps%5Bapp1%5D=xxx&apps%5Bapp2%5D=yyy') }
  end

  describe '#uat_host' do
    let(:url) { "#{base_url}?uat_url=http://uat.com&apps%5Bapp1%5D=xxx&apps%5Bapp2%5D=yyy" }

    subject { FeatureReview.new(url: url, versions: %w(xxx yyy)).uat_host }

    it { is_expected.to eq('uat.com') }

    context 'when scheme is missing' do
      let(:url) { "#{base_url}?uat_url=uat.com&apps%5Bapp1%5D=xxx&apps%5Bapp2%5D=yyy" }
      it { is_expected.to eq('uat.com') }
    end

    context 'when uat_url is missing' do
      let(:url) { "#{base_url}?apps%5Bapp1%5D=xxx&apps%5Bapp2%5D=yyy" }
      it { is_expected.to be_nil }
    end
  end

  describe '#uat_url' do
    let(:url) { "#{base_url}?uat_url=http://uat.com&apps%5Bapp1%5D=xxx&apps%5Bapp2%5D=yyy" }

    subject { FeatureReview.new(url: url, versions: %w(xxx yyy)).uat_url }

    it { is_expected.to eq('http://uat.com') }

    context 'when scheme is missing' do
      let(:url) { "#{base_url}?uat_url=uat.com&apps%5Bapp1%5D=xxx&apps%5Bapp2%5D=yyy" }
      it { is_expected.to eq('http://uat.com') }
    end

    context 'when uat_url is missing' do
      let(:url) { "#{base_url}?apps%5Bapp1%5D=xxx&apps%5Bapp2%5D=yyy" }
      it { is_expected.to be_nil }
    end
  end

  describe '#app_versions' do
    let(:url) { "#{base_url}?apps%5Bapp1%5D=xxx&apps%5Bapp2%5D=yyy&apps%5Bapp3%5D" }

    subject { FeatureReview.new(url: url, versions: %w(xxx yyy)).app_versions }

    it { is_expected.to eq('app1' => 'xxx', 'app2' => 'yyy') }
  end

  describe '#base_url' do
    let(:url) { 'www.something.com/something?uat_url=http://uat.com&apps%5Bapp1%5D=xxx&apps%5Bapp2%5D=yyy' }

    subject { FeatureReview.new(url: url, versions: %w(xxx yyy)).base_url }

    it { is_expected.to eq('www.something.com/something') }
  end

  describe '#query_hash' do
    let(:url) { 'www.something.com/something?uat_url=uat.com&apps%5Bapp1%5D=xxx&apps%5Bapp2%5D=yyy' }

    subject { FeatureReview.new(url: url, versions: %w(xxx yyy)).query_hash }

    it {
      is_expected.to eq(
        'apps' => { 'app1' => 'xxx', 'app2' => 'yyy' },
        'uat_url' => 'uat.com',
      )
    }
  end
end
