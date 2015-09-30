require 'rack/utils'
require 'uri'

require 'feature_review'

module Factories
  class FeatureReviewFactory
    QUERY_PARAM_WHITELIST = %w(apps uat_url)

    def create_from_text(text)
      URI.extract(text, %w(http https))
        .map { |uri| parse_uri(uri) }
        .compact
        .select { |url| url.path == '/feature_reviews' }
        .map { |url| create_from_url_string(url) }
    end

    def create_from_url_string(url)
      uri = Addressable::URI.parse(url)
      query_hash = Rack::Utils.parse_nested_query(uri.query)
      versions = query_hash.fetch('apps', {}).values.reject(&:blank?)
      create(
        path: whitelisted_path(uri, query_hash),
        versions: versions,
      )
    end

    def create(attrs)
      FeatureReview.new(attrs)
    end

    def create_from_tickets(tickets)
      map_paths(tickets)
        .map { |path| create_from_url_string(path) }
    end

    private

    def whitelisted_path(uri, query_hash)
      "#{uri.path}?#{query_hash.extract!(*QUERY_PARAM_WHITELIST).to_query}"
    end

    def map_paths(tickets)
      tickets.map(&:paths).flatten.uniq
    end

    def parse_uri(uri)
      URI.parse(uri)
    rescue URI::InvalidURIError
      nil
    end
  end
end
