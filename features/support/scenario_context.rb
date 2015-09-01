require 'support/git_test_repository'
require 'support/feature_review_helpers'
require 'git_repository_location'

require 'rack/test'
require 'factory_girl'

module Support
  class ScenarioContext
    include Support::FeatureReviewHelpers

    def initialize(app, host)
      @app = app # used by rack-test
      @host = host
      @application = nil
      @repos = {}
      @tickets = {}
      @review_urls = {}
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

    def create_and_start_ticket(key:, summary:)
      ticket_details1 = { key: key, summary: summary, status: 'To Do' }
      ticket_details2 = ticket_details1.merge(status: 'In Progress')

      [ticket_details1, ticket_details2].each do |ticket_details|
        event = build(:jira_event, ticket_details)
        post_event 'jira', event.details

        @tickets[key] = ticket_details.merge(issue_id: event.issue_id)
      end
    end

    def prepare_review(apps, uat_url, feature_review_nickname, time = nil)
      apps_hash = {}
      apps.each do |app|
        apps_hash[app[:app_name]] = resolve_version(app[:version])
      end

      @review_urls[feature_review_nickname] = UrlBuilder.new(@host).build(apps_hash, uat_url, time)
    end

    def link_ticket_and_feature_review(jira_key, feature_review_nickname)
      url = review_url(feature_review_nickname)
      ticket_details = @tickets.fetch(jira_key)
      event = build(:jira_event, ticket_details.merge!(comment_body: "Here you go: #{url}"))
      post_event 'jira', event.details
    end

    def approve_ticket(jira_key, approver_email:, time:)
      ticket_details = @tickets.fetch(jira_key).except(:status)
      event = build(
        :jira_event,
        :approved,
        ticket_details.merge!(user_email: approver_email, updated: time),
      )
      post_event 'jira', event.details
    end

    def review_url(feature_review_nickname = nil)
      @review_urls.fetch(feature_review_nickname, @review_urls.values.last)
    end

    def review_path(feature_review_nickname = nil)
      url_to_path(review_url(feature_review_nickname))
    end

    def review_urls
      fail 'Review url not set' unless @review_urls
      @review_urls.values
    end

    def review_paths
      review_urls.map { |review_url| url_to_path(review_url) }
    end

    private

    attr_reader :app

    include Rack::Test::Methods

    def url_to_path(url)
      URI.parse(url).request_uri if url
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
