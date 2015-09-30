require 'events/jira_event'
require 'snapshots/ticket'
require 'ticket'

require 'addressable/uri'

module Repositories
  class TicketRepository
    def initialize(store = Snapshots::Ticket,
      git_repository_location: GitRepositoryLocation)
      @store = store
      @git_repository_location = git_repository_location
      @feature_review_factory = Factories::FeatureReviewFactory.new
    end

    delegate :table_name, to: :store

    def tickets_for_path(feature_review_path, at: nil)
      query = at ? store.arel_table['event_created_at'].lteq(at) : nil
      store
        .select('DISTINCT ON (key) *')
        .where('paths @> ARRAY[?]', prepare_path(feature_review_path))
        .where(query)
        .order('key, id DESC')
        .map { |t| Ticket.new(t.attributes) }
    end

    def tickets_for_versions(versions)
      store
        .select('DISTINCT ON (key) *')
        .where('versions && ARRAY[?]::varchar[]', versions)
        .order('key, id DESC')
        .map { |t| Ticket.new(t.attributes) }
    end

    def find_last_by_key(key)
      store.where(key: key).order('id ASC').last
    end

    def apply(event)
      return unless event.is_a?(Events::JiraEvent) && event.issue?

      last_ticket = (store.where(key: event.key).last.try(:attributes) || {}).except('id')

      feature_reviews = feature_review_factory.create_from_text(event.comment)

      new_ticket = last_ticket.merge(
        'key' => event.key,
        'summary' => event.summary,
        'status' => event.status,
        'paths' => merge_ticket_paths(last_ticket, feature_reviews),
        'event_created_at' => event.created_at,
        'versions' => merge_ticket_versions(last_ticket, feature_reviews),
        'approved_at' => merge_approved_at(last_ticket, event),
      )

      store.create!(new_ticket)
      # TODO: maybe only do this for comment with FR.
      update_pull_requests_for(new_ticket) if update_pull_request?(event)
    end

    private

    attr_reader :store, :git_repository_location, :feature_review_factory

    def update_pull_request?(event)
      event.approval? || event.unapproval? || event.comment.present?
    end

    def merge_ticket_paths(ticket, feature_reviews)
      old_paths = ticket.fetch('paths', [])
      new_paths = feature_review_paths(feature_reviews)
      old_paths.concat(new_paths).uniq
    end

    def merge_ticket_versions(ticket, feature_reviews)
      old_versions = ticket.fetch('versions', [])
      new_versions = feature_review_versions(feature_reviews)
      old_versions.concat(new_versions).uniq
    end

    def merge_approved_at(last_ticket, event)
      return nil unless Ticket.new(status: event.status).approved?
      last_ticket['approved_at'] || event.created_at
    end

    def prepare_path(path)
      Addressable::URI.parse(path).normalize.to_s
    end

    def feature_review_paths(feature_reviews)
      feature_reviews.map { |feature_review|
        prepare_path(feature_review.path)
      }
    end

    def feature_review_versions(feature_reviews)
      feature_reviews.map(&:versions).flatten
    end

    def update_pull_requests_for(ticket_hash)
      ticket = Ticket.new(ticket_hash)
      feature_review_factory.create_from_tickets([ticket]).each do |feature_review|
        feature_review.app_versions.each do |app_name, version|
          # TODO: only if not already send for same app and version
          repository_location = git_repository_location.find_by_name(app_name)
          PullRequestUpdateJob.perform_later(
            repo_url: repository_location.uri,
            sha: version,
          ) if repository_location
        end
      end
    end
  end
end
