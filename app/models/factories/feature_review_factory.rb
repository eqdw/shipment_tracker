require 'uri'
require 'rack/utils'
require 'feature_review'

module Factories
  class FeatureReviewFactory
    def create_from_text(text)
      URI.extract(text, %w(http https))
        .map { |uri| parse_uri(uri) }
        .compact
        .select { |url| url.path == '/feature_reviews' }
        .map { |url| create_from_url_string(url) }
    end

    def create_from_url_string(url)
      query_hash = Rack::Utils.parse_nested_query(URI(url).query)
      versions = query_hash.fetch('apps', {}).values.reject(&:blank?)
      create(
        path: url.to_s,
        versions: versions,
      )
    end

    def create(attrs)
      FeatureReview.new(attrs)
    end

    private

    def parse_uri(uri)
      URI.parse(uri)
    rescue URI::InvalidURIError
      nil
    end
  end
end
