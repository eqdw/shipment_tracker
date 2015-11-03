require 'rails_helper'

RSpec.describe Queries::ReleasesQuery do
  subject(:releases_query) {
    Queries::ReleasesQuery.new(
      per_page: 50,
      git_repo: git_repository,
      app_name: app_name,
    )
  }

  let(:deploy_repository) { instance_double(Repositories::DeployRepository) }
  let(:ticket_repository) { instance_double(Repositories::TicketRepository) }
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
  let(:approval_time) { time - 2.hours }

  let(:deploys) {
    [
      Deploy.new(version: 'def', app_name: app_name, event_created_at: deploy_time, deployed_by: 'auser'),
    ]
  }
  let(:approved_ticket) {
    Ticket.new(
      versions: %w(xyz uvw),
      paths: ['/feature_reviews?apps%5Bapp1%5D=xyz&apps%5Bapp2%5D=uvw'],
      status: 'Done',
      approved_at: approval_time,
    )
  }
  let(:not_approved_ticket) {
    Ticket.new(
      versions: ['abc'],
      paths: ['/feature_reviews?apps%5Bapp1%5D=abc'],
    )
  }
  let(:tickets) { [approved_ticket, not_approved_ticket] }

  before do
    allow(Repositories::DeployRepository).to receive(:new).and_return(deploy_repository)
    allow(Repositories::TicketRepository).to receive(:new).and_return(ticket_repository)
    allow(git_repository).to receive(:recent_commits_on_main_branch).with(50).and_return(commits)
    allow(deploy_repository).to receive(:deploys_for_versions).with(versions, environment: 'production')
      .and_return(deploys)
    allow(ticket_repository).to receive(:tickets_for_versions).with(associated_versions)
      .and_return(tickets)
  end

  describe '#versions' do
    subject(:query_versions) { releases_query.versions }
    it 'returns all versions' do
      expect(query_versions).to eq(%w(abc def ghi))
    end
  end

  describe '#pending_releases' do
    subject(:pending_releases) { releases_query.pending_releases }
    it 'returns list of releases not yet deployed to production' do
      not_approved_feature_review = FeatureReview.new(
        versions: not_approved_ticket.versions,
        path: not_approved_ticket.paths.first,
      )

      expect(pending_releases.map(&:version)).to eq(['abc'])
      expect(pending_releases.map(&:subject)).to eq(['new commit on master'])
      expect(pending_releases.map(&:production_deploy_time)).to eq([nil])
      expect(pending_releases.map(&:deployed_by)).to eq([nil])
      expect(pending_releases.map(&:approved?)).to eq([false])
      expect(pending_releases.map(&:feature_reviews)).to eq([[not_approved_feature_review]])
      expect(pending_releases.map(&:feature_reviews).flatten.first.approved?).to eq(false)
    end
  end

  describe '#deployed_releases' do
    subject(:deployed_releases) { releases_query.deployed_releases }
    it 'returns list of releases deployed to production' do
      approved_feature_review = FeatureReview.new(
        versions: approved_ticket.versions,
        path: approved_ticket.paths.first,
      )

      expect(deployed_releases.map(&:version)).to eq(%w(def ghi))
      expect(deployed_releases.map(&:subject)).to eq(['merge commit', 'first commit on master branch'])
      expect(deployed_releases.map(&:production_deploy_time)).to eq([deploy_time, nil])
      expect(deployed_releases.map(&:deployed_by)).to eq(['auser', nil])
      expect(deployed_releases.map(&:approved?)).to eq([true, false])
      expect(deployed_releases.map(&:feature_reviews)).to eq([[approved_feature_review], []])
      expect(deployed_releases.map(&:feature_reviews).flatten.first.approved_at).to eq(approval_time)
    end
  end
end
