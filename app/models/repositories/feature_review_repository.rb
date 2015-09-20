require 'events/jira_event'
require 'snapshots/feature_review'

module Repositories
  class FeatureReviewRepository
    def initialize(store = Snapshots::FeatureReview, ticket_repository: Repositories::TicketRepository.new)
      @store = store
      @ticket_repository = ticket_repository
      @factory = Factories::FeatureReviewFactory.new
    end

    delegate :table_name, to: :store

    def feature_reviews_for_versions(versions, at: nil)
      query = at ? store.arel_table['event_created_at'].lteq(at) : nil

      store
        .where(query)
        .where('versions && ARRAY[?]::varchar[]', versions)
        .group_by(&:path)
        .map { |_, snapshots|
          most_recent = snapshots.max_by(&:event_created_at)
          factory.create(
            path: most_recent.path,
            versions: most_recent.versions,
            approved_at: most_recent.approved_at,
          )
        }
    end

    def feature_review_for_path(path, at: nil)
      query = at ? store.arel_table['event_created_at'].lteq(at) : nil
      snapshot = store.where(query).where(path: path).last
      factory.create(snapshot.attributes) if snapshot
    end

    def most_recent_snapshot(path = nil)
      return store.last if path.nil?
      store.where(path: path).last
    end

    def apply(event)
      return unless relevant?(event)
      feature_review_paths = ticket_repository.most_recent_snapshot(event.key).try(:paths) || []
      create_snapshots_from_paths(feature_review_paths, event)
    end

    private

    attr_reader :store, :ticket_repository, :factory

    def relevant?(event)
      event.is_a?(Events::JiraEvent) && event.issue? &&
        (event.approval? || event.unapproval? || event.comment.present?)
    end

    def create_snapshots_from_paths(feature_review_paths, event)
      feature_review_paths.each do |feature_review_path|
        feature_review = factory.create_from_url_string(feature_review_path)

        store.create!(
          path: feature_review.path,
          versions: feature_review.versions,
          event_created_at: event.created_at,
          approved_at: approved_at_for(feature_review, event),
        )
      end
    end

    def approved_at_for(feature_review, event)
      return unless approved?(feature_review, at: event.created_at)
      most_recent_snapshot(feature_review.path).try(:approved_at) || event.created_at
    end

    def approved?(feature_review, at:)
      tickets = ticket_repository.tickets_for(feature_review_path: feature_review.path, at: at)
      return false if tickets.empty?
      tickets.all?(&:approved?)
    end
  end
end
