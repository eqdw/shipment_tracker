require 'rails_helper'
require 'support/git_test_repository'
require 'support/repository_builder'

require 'benchmark'
require 'fileutils'
require 'csv'

RSpec.describe 'Projection performance', type: :request do
  before(:all) do
    login_with_omniauth
  end

  describe 'Feature Review' do
    let(:apps) { { 'frontend' => 'abc', 'backend' => 'def' } }
    let(:server) { 'uat.fc.com' }
    let(:url) { feature_review_url(apps, server) }
    let(:path) { URI.parse(url).request_uri }

    it 'measures the request time' do
      csv(name: 'feature_review', headers: ['Event Count', 'Time to Run']) do |file|
        progression do |event_count|
          create :jira_event, comment_body: "Here you go: #{url}"
          create :circle_ci_event, version: apps['frontend']
          apps.each do |name, version|
            create :deploy_event, server: server, app_name: name, version: version
          end
          create :manual_test_event, apps: apps
          create :uat_event, server: server

          file << benchmark(event_count) do
            get(path)
          end
        end
      end
    end
  end

  describe 'Feature Review Search' do
    let(:apps) { { 'frontend' => version, 'backend' => 'def' } }
    let(:server) { 'uat.fc.com' }
    let(:url) { feature_review_url(apps, server) }

    let(:repo_name) { 'frontend' }
    let(:test_git_repo) { Support::GitTestRepository.new }
    let(:repository_builder) { Support::RepositoryBuilder.new(test_git_repo) }

    before do
      repository_builder.build(git_diagram)
      GitRepositoryLocation.create(name: repo_name, uri: "file://#{test_git_repo.dir}")
    end

    context 'with a simple repo so that git has minimal effect on performance' do
      let(:git_diagram) { '-A' }
      let(:version) { test_git_repo.commit_for_pretend_version('A') }

      it 'measures the request time' do
        csv(name: 'feature_review_search', headers: ['Event Count', 'Time to Run']) do |file|
          progression do |event_count|
            create :jira_event, comment_body: "Here you go: #{url}"

            file << benchmark(event_count) do
              get(search_feature_reviews_path, application: 'frontend', version: version)
            end
          end
        end
      end
    end
  end

  describe 'Releases' do
    let(:apps) { { 'frontend' => version, 'backend' => 'def' } }
    let(:server) { 'uat.fc.com' }
    let(:url) { feature_review_url(apps, server) }

    let(:repo_name) { 'frontend' }
    let(:test_git_repo) { Support::GitTestRepository.new }
    let(:repository_builder) { Support::RepositoryBuilder.new(test_git_repo) }

    let(:version) { test_git_repo.commit_for_pretend_version('B') }
    let(:git_diagram) do
      <<-'EOS'
          o-o-o-o-o-A-B
         /             \
       -o-------o-------C
      EOS
    end

    before do
      GitRepositoryLocation.create(name: repo_name, uri: "file://#{test_git_repo.dir}")
    end

    # Note that the git diagram contains 10 commits. So each time it's built you get (10 * count) commits.
    def add_branches(count)
      count.times do
        repository_builder.build(git_diagram)
      end
    end

    context 'when commits grow linearly and events stay constant' do
      it 'measures the request time' do
        csv(name: 'releases_commits', headers: ['Commit Count', 'Event Count', 'Time to Run']) do |file|
          progression(start: 1_000) do |event_count|
            add_branches(300)

            create_events(1000)

            create :jira_event, comment_body: "Here you go: #{url}"

            apps.each do |name, sha|
              create :deploy_event, server: server, app_name: name, version: sha, environment: 'production'
            end

            file << benchmark(event_count, with_commit_count: true, with_events: false) do
              get release_path(repo_name)
            end

            expect(response).to be_ok
          end
        end
      end
    end

    context 'when commits stay constant and events grow linearly' do
      it 'measures the request time' do
        add_branches(500)
        csv(name: 'releases_events', headers: ['Commit Count', 'Event Count', 'Time to Run']) do |file|
          progression(start: 1_000) do |event_count|
            create :jira_event, comment_body: "Here you go: #{url}"

            apps.each do |name, sha|
              create :deploy_event, server: server, app_name: name, version: sha, environment: 'production'
            end

            file << benchmark(event_count, with_commit_count: true, with_events: true) do
              get release_path(repo_name)
            end

            expect(response).to be_ok
          end
        end
      end
    end

    context 'when commits and events grow linearly' do
      it 'measures the request time' do
        branch_count = 100

        csv(name: 'releases', headers: ['Commit Count', 'Event Count', 'Time to Run']) do |file|
          progression(start: 1_000, points: 5) do |event_count|
            add_branches(branch_count)
            branch_count *= 2

            create :jira_event, comment_body: "Here you go: #{url}"

            apps.each do |name, sha|
              create :deploy_event, server: server, app_name: name, version: sha, environment: 'production'
            end

            file << benchmark(event_count, with_commit_count: true, with_events: true) do
              get release_path(repo_name)
            end

            expect(response).to be_ok
          end
        end
      end
    end
  end

  private

  def create_events(count)
    number = (count / 6).to_i

    build_events(type: :jira_event, number: number, key: 'JIRA-$ID')
    build_events(type: :circle_ci_event, number: number)
    build_events(type: :jenkins_event, number: number)
    build_events(type: :deploy_event, number: number)
    build_events(type: :manual_test_event, number: number)
    build_events(type: :uat_event, number: number)
  end

  def drop_events
    Events::BaseEvent.delete_all
  end

  def updater
    Repositories::Updater.from_rails_config
  end

  def create_snapshots
    updater.run
  end

  def drop_snapshots
    updater.reset
  end

  def benchmark(count, with_commit_count: false, with_events: true, &block)
    create_events(count) if with_events
    create_snapshots

    time_to_run = Benchmark.realtime(&block)

    if with_commit_count
      results = [test_git_repo.total_commits, Events::BaseEvent.count, time_to_run]
      puts "#{results[0]} commits, #{results[1]} events -> #{results[2].round(1)} seconds"
    else
      results = [Events::BaseEvent.count, time_to_run]
      puts "#{results[0]} events -> #{results[1].round(1)} seconds"
    end

    drop_snapshots
    drop_events

    results
  end

  def csv(name:, headers:, &block)
    filename = Rails.root.join('performance', "#{name}.csv")
    FileUtils.mkdir_p File.dirname(filename)
    CSV.open(filename, 'wb') do |csv_contents|
      csv_contents << headers
      block.call(csv_contents)
    end
  end

  def progression(start: 10_000, points: 10, factor: 2, &block)
    (points - 1).times.reduce([start]) { |a, _e| a << a.last * factor }.each do |count|
      block.call(count)
    end
  end

  def build_events(type:, number:, **args)
    blueprint = build(type, args)
    Events::BaseEvent.connection.execute(<<-QUERY)
      INSERT INTO events (
          details,
          created_at,
          updated_at,
          type
        )
        SELECT json (replace('#{blueprint.details.to_json}', '$ID', ids.id::text)),
               now(),
               now(),
               '#{blueprint.type}'
        FROM (SELECT generate_series(1, #{number}) AS id) AS ids;
    QUERY
  end
end
