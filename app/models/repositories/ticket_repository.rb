require 'events/jira_event'
require 'snapshots/ticket'
require 'ticket'

require 'addressable/uri'

module Repositories
  class TicketRepository
    def initialize(store = Snapshots::Ticket)
      @store = store
    end

    delegate :table_name, to: :store

    def tickets_for_feature_review_urls(feature_review_url:, at: nil)
      query = at ? store.arel_table['event_created_at'].lteq(at) : nil
      store
        .select('DISTINCT ON (key) *')
        .where('urls @> ARRAY[?]', prepare_url(feature_review_url))
        .where(query)
        .order('key, id DESC')
        .map { |t| Ticket.new(t.attributes) }
    end

    # def tickets_for_versions(versions)
    #   store
    #     .select('DISTINCT ON (key) *')
    #     .where('versions && ARRAY[?]::varchar[]', versions)
    #     .order('key, id DESC')
    #     .map { |t| Ticket.new(t.attributes) }
    # end

    def apply(event)
      return unless event.is_a?(Events::JiraEvent) && event.issue?

      last_ticket = (store.where(key: event.key).last.try(:attributes) || {}).except('id')

      feature_reviews = Factories::FeatureReviewFactory.new.create_from_text(event.comment)

      new_ticket = last_ticket.merge(
        'key' => event.key,
        'summary' => event.summary,
        'status' => event.status,
        'urls' => merge_ticket_urls(last_ticket, feature_reviews),
        'event_created_at' => event.created_at,
        'versions' => merge_ticket_versions(last_ticket, feature_reviews),
      )

      store.create!(new_ticket)
    end

    private

    attr_reader :store

    # def tickets(feature_review_url, at)
    #   query = at ? store.arel_table['event_created_at'].lteq(at) : nil
    #   store
    #     .select('DISTINCT ON (key) *')
    #     .where('urls @> ARRAY[?]', prepare_url(feature_review_url))
    #     .where(query)
    #     .order('key, id DESC')
    #     .map { |t| Ticket.new(t.attributes) }
    # end

    def merge_ticket_urls(ticket, feature_reviews)
      old_urls = ticket.fetch('urls', [])
      new_urls = feature_review_urls(feature_reviews)
      old_urls.concat(new_urls).uniq
    end

    def merge_ticket_versions(ticket, feature_reviews)
      old_versions = ticket.fetch('versions', [])
      new_versions = feature_review_versions(feature_reviews)
      old_versions.concat(new_versions).uniq
    end

    def prepare_url(url_string)
      Addressable::URI.parse(url_string).normalize.to_s
    end

    def feature_review_urls(feature_reviews)
      feature_reviews.map { |feature_review|
        prepare_url(feature_review.url)
      }
    end

    def feature_review_versions(feature_reviews)
      feature_reviews.map(&:versions).flatten
    end
  end
end
