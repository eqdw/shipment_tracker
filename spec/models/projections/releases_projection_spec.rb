require 'rails_helper'

RSpec.describe Projections::ReleasesProjection do
  subject(:projection) {
    Projections::ReleasesProjection.new(
      per_page: 50,
      git_repository: git_repository,
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
  let(:feature_reviews) {
    [
      Snapshots::FeatureReview.create!(
        url: feature_review_url(frontend: 'abc', backend: 'NON1'),
        versions: %w(NON1 abc),
        event_created_at: 1.day.ago,
      ),
      Snapshots::FeatureReview.create!(
        url: feature_review_url(frontend: 'NON2', backend: 'def'),
        versions: %w(def NON2),
        event_created_at: 3.days.ago,
      ),
      Snapshots::FeatureReview.create!(
        url: feature_review_url(frontend: 'NON2', backend: 'NON3'),
        versions: %w(NON3 NON2),
        event_created_at: 5.days.ago,
      ),
      Snapshots::FeatureReview.create!(
        url: feature_review_url(frontend: 'ghi', backend: 'NON3'),
        versions: %w(NON3 ghi),
        event_created_at: 7.days.ago,
      ),
      Snapshots::FeatureReview.create!(
        url: feature_review_url(frontend: 'NON4', backend: 'NON5'),
        versions: %w(NON5 NON4),
        event_created_at: 9.days.ago,
      ),
    ]
  }

  before do
    allow(Repositories::DeployRepository).to receive(:new).and_return(deploy_repository)
    allow(Repositories::FeatureReviewRepository).to receive(:new).and_return(feature_review_repository)
    allow(git_repository).to receive(:recent_commits).with(50).and_return(commits)
    allow(deploy_repository).to receive(:deploys_for_versions).with(versions, environment: 'production')
      .and_return(deploys)
  end

  describe '#pending_releases' do
    it 'returns list of releases not yet deployed to production' do
      expect(projection.pending_releases.length).to eq(1)

      release = projection.pending_releases.first
      expect(release.version).to eq('abc')
      expect(release.subject).to eq('commit on topic branch')
    end

    describe 'returned releases' do
      it 'have feature_reviews' do
        expect(projection.deployed_releases).to all(respond_to(:feature_reviews))
      end

      it 'have an approval_status and know whether they are approved' do
        expect(projection.pending_releases).to all(respond_to(:approved?))
        expect(projection.pending_releases).to all(respond_to(:approval_status))
      end
    end
  end

  describe '#deployed_releases' do
    it 'returns list of releases deployed to production' do
      expect(projection.deployed_releases.length).to eq(2)

      expect(projection.deployed_releases.any? { |release|
        release.version == 'def' && release.subject == 'commit on topic branch'
      }).to eq(true)

      expect(projection.deployed_releases.any? { |release|
        release.version == 'ghi' && release.subject == 'commit on master branch'
      }).to eq(true)
    end

    describe 'returned releases' do
      it 'know production_deploy_time' do
        expect(projection.deployed_releases).to all(respond_to(:production_deploy_time))
      end

      it 'have feature_reviews' do
        expect(projection.deployed_releases).to all(respond_to(:feature_reviews))
      end

      it 'have an approval_status and know whether they are approved' do
        expect(projection.deployed_releases).to all(respond_to(:approved?))
        expect(projection.deployed_releases).to all(respond_to(:approval_status))
      end
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
