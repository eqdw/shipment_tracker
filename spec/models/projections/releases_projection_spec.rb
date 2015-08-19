require 'rails_helper'
require 'projections/releases_projection'
require 'git_commit'

RSpec.describe Projections::ReleasesProjection do
  subject(:projection) {
    Projections::ReleasesProjection.new(
      per_page: 50,
      git_repository: git_repository,
      app_name: app_name,
    )
  }

  let(:deploy_repository) { instance_double(Repositories::DeployRepository) }
  let(:git_repository) { instance_double(GitRepository) }
  let(:app_name) { 'foo' }
  let(:time) { Time.current }
  let(:formatted_time) { time.to_formatted_s(:long_ordinal) }

  let(:commits) {
    [
      GitCommit.new(id: 'abc', message: "commit on topic branch\n\nchild of def", time: time - 1.hour),
      GitCommit.new(id: 'def', message: "commit on topic branch\n\nchild of ghi", time: time - 2.hours),
      GitCommit.new(id: 'ghi', message: 'commit on master branch', time: time - 3.hours),
    ]
  }

  let(:versions) { commits.map(&:id) }

  let(:deploys) { [Deploy.new(version: 'def', app_name: app_name, event_created_at: time)] }

  let(:events) {
    [
      build(:jira_event, key: 'JIRA-1', comment_body: feature_review_comment(foo: 'abc')),
      build(:jira_event, key: 'JIRA-2', comment_body: feature_review_comment(foo: 'abc', bar: 'jkl')),
      build(:jira_event, key: 'JIRA-3', comment_body: feature_review_comment(foo: 'xyz')),
      build(:jira_event, :approved, key: 'JIRA-2'),
    ]
  }

  before do
    allow(Repositories::DeployRepository).to receive(:new).and_return(deploy_repository)
    allow(git_repository).to receive(:recent_commits).with(50).and_return(commits)
    allow(git_repository).to receive(:get_dependent_commits).with('abc')
      .and_return([GitCommit.new(id: 'def')])
    allow(deploy_repository).to receive(:deploys_for_versions).with(versions, environment: 'production')
      .and_return(deploys)
  end

  describe '#pending_releases' do
    it 'returns the list of releases not yet deployed to production' do
      projection.apply_all(events)

      expect(projection.pending_releases).to eq(
        [
          Release.new(
            version: 'abc',
            subject: 'commit on topic branch',
            time: nil,
            feature_review_status: 'Ready for Deployment',
            feature_review_path: feature_review_path(foo: 'abc', bar: 'jkl'), # Only shows last associated FR
            approved: true, # A release has max one FR, so approved even when FR for JIRA-1 is not approved
          ),
        ],
      )
    end
  end

  describe '#deployed_releases' do
    it 'returns the list of releases deployed to production' do
      projection.apply_all(events)

      expect(projection.deployed_releases).to eq(
        [
          Release.new(
            version: 'def',
            subject: 'commit on topic branch',
            time: formatted_time,
            feature_review_status: 'Ready for Deployment',
            feature_review_path: feature_review_path(foo: 'abc', bar: 'jkl'),
            approved: true,
          ),
          Release.new(
            version: 'ghi',
            subject: 'commit on master branch',
            time: nil,
            feature_review_path: nil,
            approved: false,
          ),
        ],
      )
    end
  end

  private

  def feature_review_comment(apps)
    "please review\n#{feature_review_url(apps)}"
  end

  def feature_review_path(apps)
    URI.parse(feature_review_url(apps)).request_uri
  end
end
