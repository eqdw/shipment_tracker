require 'rails_helper'

RSpec.describe Queries::ReleasesQuery do
  subject(:releases_query) {
    Queries::ReleasesQuery.new(
      per_page: 50,
      git_repo: git_repository,
      deploy_repo: deploy_repository,
      feature_review_repo: feature_review_repository,
      app_name: app_name,
    )
  }

  let(:deploy_repository) { instance_double(Repositories::DeployRepository) }
  let(:ticket_repository) { instance_double(Repositories::TicketRepository) }
  let(:feature_review_repository) { instance_double(Repositories::FeatureReviewRepository) }
  let(:git_repository) { instance_double(GitRepository) }

  let(:app_name) { 'foo' }
  let(:time) { Time.current }
  let(:formatted_time) { time.to_formatted_s(:long_ordinal) }

  let(:commits) {
    [
      GitCommit.new(id: 'abc', message: 'new commit on master', time: time - 1.hour, parent_ids: ['def']),
      GitCommit.new(id: 'def', message: 'merge commit', time: time - 2.hours, parent_ids: %w(ghi xyz)),
      GitCommit.new(id: 'ghi', message: 'first commit on master branch', time: time - 3.hours),
    ]
  }

  let(:versions) { commits.map(&:id) }
  let(:associated_versions) { %w(abc def xyz ghi) }
  let(:deploy_time) { time - 1.hour }

  let(:deploys) { [Deploy.new(version: 'def', app_name: app_name, event_created_at: deploy_time)] }
  let(:approved_feature_review) { FeatureReview.new(versions: ['xyz'], approved_at: time - 2.hours) }
  let(:not_approved_feature_review) { FeatureReview.new(versions: ['abc']) }
  let(:feature_reviews) { [approved_feature_review, not_approved_feature_review] }

  before do
    allow(Repositories::FeatureReviewRepository).to receive(:new).and_return(feature_review_repository)
    allow(git_repository).to receive(:recent_commits_on_main_branch).with(50).and_return(commits)
    allow(deploy_repository).to receive(:deploys_for_versions).with(versions, environment: 'production')
      .and_return(deploys)
    allow(feature_review_repository).to receive(:feature_reviews_for_versions).with(associated_versions)
      .and_return(feature_reviews)
  end

  describe '#pending_releases' do
    subject(:pending_releases) { releases_query.pending_releases }
    it 'returns list of releases not yet deployed to production' do
      expect(pending_releases.map(&:version)).to eq(['abc'])
      expect(pending_releases.map(&:subject)).to eq(['new commit on master'])
      expect(pending_releases.map(&:production_deploy_time)).to eq([nil])
      expect(pending_releases.map(&:approval_status)).to eq([:not_approved])
      expect(pending_releases.map(&:approved?)).to eq([false])
      expect(pending_releases.map(&:feature_reviews)).to eq([[not_approved_feature_review]])
    end
  end

  describe '#deployed_releases' do
    subject(:deployed_releases) { releases_query.deployed_releases }
    it 'returns list of releases deployed to production' do
      expect(deployed_releases.map(&:version)).to eq(%w(def ghi))
      expect(deployed_releases.map(&:subject)).to eq(['merge commit', 'first commit on master branch'])
      expect(deployed_releases.map(&:production_deploy_time)).to eq([deploy_time, nil])
      expect(deployed_releases.map(&:approval_status)).to eq([:approved, nil])
      expect(deployed_releases.map(&:approved?)).to eq([true, false])
      expect(deployed_releases.map(&:feature_reviews)).to eq([[approved_feature_review], []])
    end
  end
end
