require 'spec_helper'
require 'queries/feature_review_query'

RSpec.describe Queries::FeatureReviewQuery do
  let(:build_repository) { instance_double(Repositories::BuildRepository) }
  let(:deploy_repository) { instance_double(Repositories::DeployRepository) }
  let(:manual_test_repository) { instance_double(Repositories::ManualTestRepository) }
  let(:ticket_repository) { instance_double(Repositories::TicketRepository) }
  let(:uatest_repository) { instance_double(Repositories::UatestRepository) }

  let(:expected_apps) { { 'app1' => '123' } }
  let(:expected_uat_host) { 'uat.example.com' }
  let(:expected_uat_url) { "http://#{expected_uat_host}" }

  let(:time) { Time.current }
  let(:feature_review) { new_feature_review(expected_apps, expected_uat_url) }

  subject(:query) { Queries::FeatureReviewQuery.new(feature_review, at: time) }

  before do
    allow(Repositories::BuildRepository).to receive(:new).and_return(build_repository)
    allow(Repositories::DeployRepository).to receive(:new).and_return(deploy_repository)
    allow(Repositories::ManualTestRepository).to receive(:new).and_return(manual_test_repository)
    allow(Repositories::TicketRepository).to receive(:new).and_return(ticket_repository)
    allow(Repositories::UatestRepository).to receive(:new).and_return(uatest_repository)
  end

  describe '#builds' do
    let(:expected_builds) { double('expected builds') }

    before do
      allow(build_repository).to receive(:builds_for)
        .with(apps: expected_apps, at: time)
        .and_return(expected_builds)
    end

    it 'delegates to the build repository' do
      expect(query.builds).to eq(expected_builds)
    end
  end

  describe '#deploys' do
    let(:expected_deploys) { double('expected deploys') }

    before do
      allow(deploy_repository).to receive(:deploys_for)
        .with(apps: expected_apps, server: expected_uat_host, at: time)
        .and_return(expected_deploys)
    end

    it 'delegates to the deploy repository' do
      expect(query.deploys).to eq(expected_deploys)
    end
  end

  describe '#qa_submission' do
    let(:expected_qa_submission) { double('expected qa submission') }
    let(:expected_versions) { expected_apps.values }

    before do
      allow(manual_test_repository).to receive(:qa_submission_for)
        .with(versions: expected_versions, at: time)
        .and_return(expected_qa_submission)
    end

    it 'delegates to the manual test repository' do
      expect(query.qa_submission).to eq(expected_qa_submission)
    end
  end

  describe '#tickets' do
    let(:expected_tickets) { double('expected tickets') }

    before do
      allow(ticket_repository).to receive(:tickets_for_feature_review_urls)
        .with(feature_review_url: feature_review.url, at: time)
        .and_return(expected_tickets)
    end

    it 'delegates to the ticket repository' do
      expect(query.tickets).to eq(expected_tickets)
    end
  end

  describe '#time' do
    it 'returns the time that the Feature Review Query is for' do
      expect(query.time).to eq(time)
    end
  end

  describe '#uatest' do
    let(:expected_uatest) { double('uatest') }
    let(:expected_versions) { expected_apps.values }

    before do
      allow(uatest_repository).to receive(:uatest_for)
        .with(versions: expected_versions, server: expected_uat_host, at: time)
        .and_return(expected_uatest)
    end

    it 'delegates to the uatest repository' do
      expect(query.uatest).to eq(expected_uatest)
    end
  end
end
