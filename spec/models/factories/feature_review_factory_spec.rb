require 'spec_helper'
require 'addressable/uri'
require 'ticket'

RSpec.describe Factories::FeatureReviewFactory do
  subject(:factory) { described_class.new }

  describe '#create_from_text' do
    let(:url1) { full_url('apps[app1]' => 'a', 'apps[app2]' => 'b') }
    let(:url2) { full_url('apps[app1]' => 'a') }

    let(:text) {
      <<-EOS
        complex feature review #{url1}
        simple feature review #{url2}
      EOS
    }

    subject(:feature_reviews) { factory.create_from_text(text) }

    it 'returns an array of Feature Reviews for each URL in the given text' do
      expect(feature_reviews).to match_array([
        FeatureReview.new(
          path: '/feature_reviews?apps%5Bapp1%5D=a&apps%5Bapp2%5D=b',
          versions: %w(a b),
        ),
        FeatureReview.new(
          path: '/feature_reviews?apps%5Bapp1%5D=a',
          versions: %w(a),
        ),
      ])
    end

    context 'when a Feature Review URL contains a non-whitelisted query param' do
      let(:url) { full_url('non-whitelisted' => 'ignoreme', 'apps[foo]' => 'bar') }
      let(:text) { "please review #{url}" }

      it 'filters it out' do
        expect(feature_reviews).to match_array([
          FeatureReview.new(
            path: '/feature_reviews?apps%5Bfoo%5D=bar',
            versions: %w(bar),
          ),
        ])
      end
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

  describe '#create_from_url_string' do
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

    it 'excludes non-whitelisted query parameters' do
      actual_url = full_url(
        'apps[a]' => '123',
        'time'    => Time.current.utc.to_s,
        'some'    => 'non-whitelisted',
      )
      expected_path = '/feature_reviews?apps%5Ba%5D=123'

      feature_review = factory.create_from_url_string(actual_url)
      expect(feature_review.versions).to eq(%w(123))
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

  describe '#create_from_tickets' do
    context 'when no tickets are given' do
      let(:tickets) { [] }

      it 'returns empty' do
        expect(factory.create_from_tickets(tickets)).to be_empty
      end
    end

    context 'when given tickets with paths' do
      let(:ticket1) {
        Ticket.new(paths: [feature_review_path(app1: 'abc', app2: 'def'), feature_review_path(app1: 'abc')])
      }
      let(:ticket2) {
        Ticket.new(paths: [feature_review_path(app1: 'abc', app2: 'def')])
      }
      let(:tickets) { [ticket1, ticket2] }

      it 'returns a unique collection of feature reviews' do
        expect(factory.create_from_tickets(tickets)).to match_array([
          FeatureReview.new(
            path: feature_review_path(app1: 'abc', app2: 'def'),
            versions: %w(abc def),
          ),
          FeatureReview.new(
            path: feature_review_path(app1: 'abc'),
            versions: %w(abc),
          ),
        ])
      end
    end
  end

  private

  def full_url(query_values)
    Addressable::URI.new(
      scheme: 'http',
      host:   'localhost',
      path:   '/feature_reviews',
      query_values: query_values,
    ).to_s
  end
end
