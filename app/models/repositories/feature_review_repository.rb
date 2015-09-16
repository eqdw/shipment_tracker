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
        .group_by(&:path)
        .map { |_, snapshots|
          most_recent_snapshot = snapshots.max_by(&:event_created_at)
          Factories::FeatureReviewFactory.new.create(
            path: most_recent_snapshot.path,
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
          path: feature_review.path,
          versions: feature_review.versions,
          event_created_at: event.created_at,
          approved_at: approved_at_for(feature_review, event),
        )
      end
    end

    private

    attr_reader :store

    def approved_at_for(feature_review, event)
      new_review = FeatureReviewWithStatuses.new(feature_review)
      return unless new_review.approved?
      last_review_approved_at(feature_review.path) || event.created_at
    end

    def last_review_approved_at(path)
      last_review = store.where(path: path).order('event_created_at, id ASC').last
      FeatureReviewWithStatuses.new(last_review).try(:approved_at)
    end
  end
end
