require 'spec_helper'
require 'addressable/uri'

RSpec.describe Factories::FeatureReviewFactory do
  subject(:factory) { described_class.new }

  describe '#create_from_text' do
    let(:url1) { full_url('other' => 'true', 'apps[app1]' => 'a', 'apps[app2]' => 'b') }
    let(:url2) { full_url('apps[app1]' => 'a') }

    let(:text) {
      <<-EOS
        complex feature review #{url1}
        simple feature review #{url2}
      EOS
    }

    subject(:feature_reviews) { factory.create_from_text(text) }

    it 'returns an array of FeatureReviews for each URL in the given text' do
      expect(feature_reviews).to match_array([
        FeatureReview.new(
          path: '/feature_reviews?apps%5Bapp1%5D=a&apps%5Bapp2%5D=b&other=true',
          versions: %w(a b),
        ),
        FeatureReview.new(
          path: '/feature_reviews?apps%5Bapp1%5D=a',
          versions: %w(a),
        ),
      ])
    end

    context 'when a URL has an irrelevant path' do
      let(:text) { 'irrelevant path http://localhost/not_important?apps[junk]=999' }

      it 'ignores it' do
        expect(feature_reviews).to be_empty
      end
    end

    context 'when a URL is unparseable' do
      let(:text) { 'unparseable http://foo.io/feature_reviews#bad]' }

      it 'ignores it' do
        expect(feature_reviews).to be_empty
      end
    end

    context 'when a URL contains an unknown schema' do
      let(:text) { 'foo:/feature_reviews' }

      it 'ignores it' do
        expect(feature_reviews).to be_empty
      end
    end
  end

  context '#create_from_url_string' do
    it 'returns a FeatureReview with the attributes from the url' do
      actual_url = full_url(
        'apps[a]' => '123',
        'apps[b]' => '456',
        'uat_url' => 'http://foo.com',
      )
      expected_path = '/feature_reviews?apps%5Ba%5D=123&apps%5Bb%5D=456&uat_url=http%3A%2F%2Ffoo.com'

      feature_review = factory.create_from_url_string(actual_url)
      expect(feature_review.versions).to eq(%w(123 456))
      expect(feature_review.uat_url).to eq('http://foo.com')
      expect(feature_review.path).to eq(expected_path)
    end

    it 'only captures non-blank versions in the url' do
      actual_url = full_url(
        'apps[a]' => '123',
        'apps[b]' => '',
        'uat_url' => 'http://foo.com',
      )
      expected_path = '/feature_reviews?apps%5Ba%5D=123&apps%5Bb%5D=&uat_url=http%3A%2F%2Ffoo.com'

      feature_review = factory.create_from_url_string(actual_url)
      expect(feature_review.versions).to eq(['123'])
      expect(feature_review.uat_url).to eq('http://foo.com')
      expect(feature_review.path).to eq(expected_path)
    end
  end

  def full_url(query_values)
    Addressable::URI.new(
      scheme: 'http',
      host:   'localhost',
      path:   '/feature_reviews',
      query_values: query_values,
    ).to_s
  end
end
