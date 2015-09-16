require 'uri'
require 'active_support/core_ext/object/to_query'
require 'factories/feature_review_factory'

module Support
  module FeatureReviewHelpers
    def feature_review_path(*args)
      UrlBuilder.build(*args)
    end

    def new_feature_review(*args)
      new_feature_review_from_url(feature_review_path(*args))
    end

    def new_feature_review_from_url(url)
      Factories::FeatureReviewFactory.new.create_from_url_string(url)
    end

    class UrlBuilder
      def self.build(*args)
        new.build(*args)
      end

      def initialize(host = 'http://test.host')
        @host = URI.parse(host)
      end

      def build(apps_hash = {}, uat_url = nil, time = nil)
        hash = { apps: apps_hash }
        hash['uat_url'] = uat_url if uat_url
        hash['time'] = time if time
        host.merge("/feature_reviews?#{hash.to_query}").to_s
      end

      private

      attr_reader :host
    end
  end
end
