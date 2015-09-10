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
          most_recent_snapshot = snapshots.max_by(&:event_created_at)
          Factories::FeatureReviewFactory.new.create(
            url: most_recent_snapshot.url,
            versions: most_recent_snapshot.versions,
            approved_at: most_recent_snapshot.approved_at,
          )
        }
    end

    def apply(event)
      return unless event.is_a?(Events::JiraEvent) && event.issue?

      feature_reviews = Factories::FeatureReviewFactory.new.create_from_text(event.comment)

      feature_reviews.each do |feature_review|
        store.create!(
          url: feature_review.url,
          versions: feature_review.versions,
          event_created_at: event.created_at,
          approved_at: approved_at_for(feature_review, event.created_at),
        )
      end
    end

    private

    attr_reader :store

    def approved_at_for(feature_review, event_time)
      new_review = FeatureReviewWithStatuses.new(feature_review)
      new_review.approved? ? (last_review_approved_at(feature_review.url) || event_time) : nil
    end

    def last_review_approved_at(url)
      last_review = store.where(url: url).order('event_created_at, id ASC').last
      FeatureReviewWithStatuses.new(last_review).try(:approved_at)
    end
  end
end
