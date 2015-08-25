require 'support/git_test_repository'
require 'support/feature_review_helpers'
require 'support/github_api_helpers'
require 'git_repository_location'

require 'webmock'
require 'rack/test'
require 'factory_girl'

module Support
  class ScenarioContext
    include Support::FeatureReviewHelpers
    include ActiveSupport::Testing::TimeHelpers
    include Support::GithubApiHelpers
    include WebMock::API

    attr_reader :stubbed_requests

    def initialize(app, host)
      @app = app # used by rack-test
      @host = host
      @application = nil
      @repos = {}
      @tickets = {}
      @reviews = {}
      @review_urls = {}
      @stubbed_requests = {}
    end

    def setup_application(name)
      dir = Dir.mktmpdir
      test_repo = Support::GitTestRepository.new(dir)

      @application = name
      @repos[name] = test_repo

      GitRepositoryLocation.create(uri: test_repo.uri, name: name)
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

    def link_ticket_and_feature_review(jira_key:, feature_review_nickname:, time: Time.current.to_s)
      url = review_url(feature_review_nickname: feature_review_nickname)
      ticket_details = @tickets.fetch(jira_key).merge!(
        comment_body: "Here you go: #{url}",
        updated: time,
      )
      @stubbed_requests['failure'] = stub_request(:post, %r{https://api.github.com/.*})
                                     .with(body: /"state":"failure"/)
                                     .and_return(status: 201)
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
      @stubbed_requests['success'] = stub_request(:post, %r{https://api.github.com/.*})
                                     .with(body: /"state":"success"/)
                                     .and_return(status: 201)
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
