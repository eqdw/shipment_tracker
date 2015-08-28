require 'events/jira_event'
require 'snapshots/feature_review'

module Repositories
  class FeatureReviewRepository
    def initialize(store = Snapshots::FeatureReview)
      @store = store
    end

    delegate :table_name, to: :store

    def feature_reviews_for(versions:, at: nil)
      query = at ? store.arel_table['event_created_at'].lteq(at) : nil

      store
        .where(query)
        .where('versions && ARRAY[?]::varchar[]', versions)
        .group_by(&:url)
        .map { |_, snapshots|
          most_recent_snapshot = snapshots.max { |s1, s2| s1.event_created_at <=> s2.event_created_at }
          Factories::FeatureReviewFactory.new.create(
            url: most_recent_snapshot.url,
            versions: most_recent_snapshot.versions,
          )
        }
    end

    def apply(event)
      return unless event.is_a?(Events::JiraEvent) && event.issue?

      Factories::FeatureReviewFactory.new.create_from_text(event.comment).each do |feature_review|
        store.create!(
          url: feature_review.url,
          versions: feature_review.versions,
          event_created_at: event.created_at,
        )
      end
    end

    private

    attr_reader :store
  end
end
