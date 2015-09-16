require 'support/git_test_repository'
require 'support/feature_review_helpers'
require 'git_repository_location'

require 'rack/test'
require 'factory_girl'

module Support
  class ScenarioContext
    include Support::FeatureReviewHelpers
    include ActiveSupport::Testing::TimeHelpers

    def initialize(app, host)
      @app = app # used by rack-test
      @host = host
      @application = nil
      @repos = {}
      @tickets = {}
      @reviews = {}
    end

    def setup_application(name)
      dir = Dir.mktmpdir

      @application = name
      @repos[name] = Support::GitTestRepository.new(dir)

      GitRepositoryLocation.create(uri: "file://#{dir}", name: name)
    end

    def repository_for(application)
      @repos[application]
    end

    def resolve_version(version)
      version.start_with?('#') ? commit_from_pretend(version) : version
    end

    def last_repository
      @repos[last_application]
    end

    def last_application
      @application
    end

    def create_and_start_ticket(key:, summary:, time: nil)
      ticket_details1 = { key: key, summary: summary, status: 'To Do' }
      ticket_details2 = ticket_details1.merge(status: 'In Progress')

      [ticket_details1, ticket_details2].each do |ticket_details|
        event = build(:jira_event, ticket_details)
        travel_to Time.zone.parse(time) do
          post_event 'jira', event.details
        end

        @tickets[key] = ticket_details.merge(issue_id: event.issue_id)
      end
    end

    def prepare_review(apps, uat_url, feature_review_nickname)
      apps_hash = {}
      apps.each do |app|
        apps_hash[app[:app_name]] = resolve_version(app[:version])
      end

      @reviews[feature_review_nickname] = {
        apps_hash: apps_hash,
        uat_url: uat_url,
      }
    end

    def link_ticket_and_feature_review(jira_key:, feature_review_nickname:, time: nil)
      url = review_url(feature_review_nickname: feature_review_nickname)
      ticket_details = @tickets.fetch(jira_key).merge!(
        comment_body: "Here you go: #{url}",
        updated: time,
      )
      event = build(:jira_event, ticket_details)
      travel_to Time.zone.parse(time) do
        post_event 'jira', event.details
      end
    end

    def approve_ticket(jira_key:, approver_email:, approve:, time: nil)
      ticket_details = @tickets.fetch(jira_key).except(:status)
      event = build(
        :jira_event,
        approve ? :approved : :rejected,
        ticket_details.merge!(user_email: approver_email, updated: time),
      )
      travel_to Time.zone.parse(time) do
        post_event 'jira', event.details
      end
    end

    def review_url(feature_review_nickname: nil, time: nil)
      review = @reviews.fetch(feature_review_nickname)
      feature_review_url(review[:apps_hash], review[:uat_url], time)
    end

    def review_path(feature_review_nickname: nil, time: nil)
      review = @reviews.fetch(feature_review_nickname)
      feature_review_path(review[:apps_hash], review[:uat_url], time)
    end

    def post_event(type, payload)
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[:event_token] = OmniAuth::AuthHash.new(provider: 'event_token', uid: type)
      url = "/events/#{type}"
      post url, payload.to_json, 'CONTENT_TYPE' => 'application/json'

      Repositories::Updater.from_rails_config.run
    end

    private

    attr_reader :app

    include Rack::Test::Methods

    def url_to_path(url)
      URI.parse(url).request_uri
    end

    def commit_from_pretend(pretend_commit)
      value = @repos.values.map { |r| r.commit_for_pretend_version(pretend_commit) }.compact.first
      fail "Could not find '#{pretend_commit}'" unless value
      value
    end

    def build(*args)
      FactoryGirl.build(*args)
    end
  end

  module ScenarioContextHelpers
    def scenario_context
      @scenario_context ||= ScenarioContext.new(app, Capybara.default_host)
    end
  end
end

World(Support::ScenarioContextHelpers)
