require 'virtus'
require 'rack/utils'
require 'addressable/uri'
require 'active_support/core_ext/object'

class FeatureReview
  include Virtus.value_object

  values do
    attribute :url, String
    attribute :versions, Array
    attribute :approved_at, DateTime
  end

  def app_versions
    query_hash.fetch('apps', {}).select { |_name, version| version.present? }
  end

  def path
    URI(url).request_uri
  end

  def uat_url
    uat_uri.try(:to_s)
  end

  def uat_host
    uat_uri.try(:host)
  end

  def query_hash
    Rack::Utils.parse_nested_query(URI(url).query)
  end

  def base_url
    Addressable::URI.parse(url).omit(:query).to_s
  end

  private

  def uat_uri
    uat_url_param = query_hash.fetch('uat_url', nil)
    Addressable::URI.heuristic_parse(uat_url_param, scheme: 'http')
  end
end
