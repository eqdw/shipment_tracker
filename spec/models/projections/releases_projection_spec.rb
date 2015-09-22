require 'rails_helper'

RSpec.describe Projections::ReleasesProjection do
  subject(:projection) {
    Projections::ReleasesProjection.new(
      per_page: 50,
      git_repo: git_repository,
      deploy_repo: deploy_repository,
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
      GitCommit.new(id: 'abc', message: "commit on topic branch\n\nchild of def", time: time - 1.hour),
      GitCommit.new(id: 'def', message: "commit on topic branch\n\nchild of ghi", time: time - 2.hours),
      GitCommit.new(id: 'ghi', message: 'commit on master branch', time: time - 3.hours),
    ]
  }

  let(:versions) { commits.map(&:id) }
  let(:deploy_time) { time - 1.hour }
  let(:deploys) { [Deploy.new(version: 'def', app_name: app_name, event_created_at: deploy_time)] }

  before do
    allow(Repositories::FeatureReviewRepository).to receive(:new).and_return(feature_review_repository)
    allow(git_repository).to receive(:recent_commits_by_first_parent).with(50).and_return(commits)
    allow(deploy_repository).to receive(:deploys_for_versions).with(versions, environment: 'production')
      .and_return(deploys)
  end

  describe '#pending_releases' do
    it 'returns list of releases not yet deployed to production' do
      versions = projection.pending_releases.map(&:version)
      expect(versions).to eq(['abc'])
    end

    it 'have appropriate methods' do
      expect(projection.pending_releases).to all(respond_to(:feature_reviews))
      expect(projection.pending_releases).to all(respond_to(:approved?))
      expect(projection.pending_releases).to all(respond_to(:approval_status))
    end
  end

  describe '#deployed_releases' do
    it 'returns list of releases deployed to production' do
      versions = projection.deployed_releases.map(&:version)
      expect(versions).to eq(%w(def ghi))
    end

    it 'have appropriate methods' do
      expect(projection.deployed_releases).to all(respond_to(:feature_reviews))
      expect(projection.deployed_releases).to all(respond_to(:approved?))
      expect(projection.deployed_releases).to all(respond_to(:approval_status))
    end
  end
end
