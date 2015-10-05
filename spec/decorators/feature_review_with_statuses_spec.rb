require 'rails_helper'
require 'feature_review_with_statuses'

RSpec.describe FeatureReviewWithStatuses do
  let(:tickets) { double(:tickets) }
  let(:builds) { double(:builds) }
  let(:deploys) { double(:deploys) }
  let(:qa_submission) { double(:qa_submission) }
  let(:uatest) { double(:uatest) }
  let(:apps) { { 'app1' => 'xxx', 'app2' => 'yyy' } }

  let(:uat_url) { 'http://uat.com' }
  let(:feature_review) { instance_double(FeatureReview, uat_url: uat_url, app_versions: apps) }
  let(:query_time) { Time.parse('2014-08-10 14:40:48 UTC') }

  subject(:decorator) {
    FeatureReviewWithStatuses.new(
      feature_review,
      builds: builds,
      deploys: deploys,
      qa_submission: qa_submission,
      tickets: tickets,
      uatest: uatest,
      at: query_time,
    )
  }

  it 'returns #builds, #deploys, #qa_submission, #tickets, #uatest and #time as initialized' do
    expect(decorator.builds).to eq(builds)
    expect(decorator.deploys).to eq(deploys)
    expect(decorator.qa_submission).to eq(qa_submission)
    expect(decorator.tickets).to eq(tickets)
    expect(decorator.uatest).to eq(uatest)
    expect(decorator.time).to eq(query_time)
  end

  context 'when initialized without builds, deploys, qa_submission, tickets, uatest and time' do
    let(:decorator) { described_class.new(feature_review) }

    it 'returns default values for #builds, #deploy,s #qa_submission, #tickets, #uatest and #time' do
      expect(decorator.builds).to eq({})
      expect(decorator.deploys).to eq([])
      expect(decorator.qa_submission).to eq(nil)
      expect(decorator.tickets).to eq([])
      expect(decorator.uatest).to eq(nil)
      expect(decorator.time).to eq(nil)
    end
  end

  it 'delegates unknown messages to the feature_review' do
    expect(decorator.uat_url).to eq(feature_review.uat_url)
  end

  describe 'generation of github links' do
    context 'when no repository location is given' do
      subject(:decorator) { FeatureReviewWithStatuses.new(feature_review) }

      it 'does not generate github links' do
        expect(decorator.github_links).to eq({})
      end
    end

    context 'when repository locations are given' do
      subject(:decorator) { FeatureReviewWithStatuses.new(feature_review, repository_locations: locations) }

      let(:repo_uri1) { 'ssh://github.com/app1.git' }
      let(:repo_uri2) { 'ssh://github.com/app2.git' }
      let(:repo_url1) { 'https://github.com/app1' }
      let(:repo_url2) { 'https://github.com/app2' }

      let(:locations) {
        [
          instance_double(GitRepositoryLocation, name: 'app1', uri: repo_uri1),
          instance_double(GitRepositoryLocation, name: 'app2', uri: repo_uri2),
          instance_double(GitRepositoryLocation, name: 'app3'),
        ]
      }

      let(:octokit_repo1) { instance_double(Octokit::Repository, url: repo_url1) }
      let(:octokit_repo2) { instance_double(Octokit::Repository, url: repo_url2) }

      before do
        allow(Octokit::Repository).to receive(:from_url).with(repo_uri1).and_return(octokit_repo1)
        allow(Octokit::Repository).to receive(:from_url).with(repo_uri2).and_return(octokit_repo2)
      end

      it 'generates github links' do
        expect(decorator.github_links).to eq('app1' => repo_url1, 'app2' => repo_url2)
      end
    end
  end

  describe '#build_status' do
    context 'when all builds pass' do
      let(:builds) do
        {
          'frontend' => Build.new(success: true),
          'backend'  => Build.new(success: true),
        }
      end

      it 'returns :success' do
        expect(decorator.build_status).to eq(:success)
      end

      context 'but some builds are missing' do
        let(:builds) do
          {
            'frontend' => Build.new(success: true),
            'backend'  => Build.new,
          }
        end

        it 'returns nil' do
          expect(decorator.build_status).to eq(nil)
        end
      end
    end

    context 'when any of the builds fails' do
      let(:builds) do
        {
          'frontend' => Build.new(success: false),
          'backend'  => Build.new(success: true),
        }
      end

      it 'returns :failure' do
        expect(decorator.build_status).to eq(:failure)
      end
    end

    context 'when there are no builds' do
      let(:builds) { {} }

      it 'returns nil' do
        expect(decorator.build_status).to be nil
      end
    end
  end

  describe '#deploy_status' do
    context 'when all deploys are correct' do
      let(:deploys) do
        [
          Deploy.new(correct: true),
        ]
      end

      it 'returns :success' do
        expect(decorator.deploy_status).to eq(:success)
      end
    end

    context 'when any deploy is not correct' do
      let(:deploys) do
        [
          Deploy.new(correct: true),
          Deploy.new(correct: false),
        ]
      end

      it 'returns :failure' do
        expect(decorator.deploy_status).to eq(:failure)
      end
    end

    context 'when there are no deploys' do
      let(:deploys) { [] }

      it 'returns nil' do
        expect(decorator.deploy_status).to be nil
      end
    end
  end

  describe '#qa_status' do
    context 'when QA submission is accepted' do
      let(:qa_submission) { QaSubmission.new(accepted: true) }

      it 'returns :success' do
        expect(decorator.qa_status).to eq(:success)
      end
    end

    context 'when QA submission is rejected' do
      let(:qa_submission) { QaSubmission.new(accepted: false) }

      it 'returns :failure' do
        expect(decorator.qa_status).to eq(:failure)
      end
    end

    context 'when QA submission is missing' do
      let(:qa_submission) { nil }

      it 'returns nil' do
        expect(decorator.qa_status).to be nil
      end
    end
  end

  describe '#uatest_status' do
    context 'when User Acceptance Tests have passed' do
      let(:uatest) { Uatest.new(success: true) }

      it 'returns :success' do
        expect(decorator.uatest_status).to eq(:success)
      end
    end

    context 'when User Acceptance Tests have failed' do
      let(:uatest) { Uatest.new(success: false) }

      it 'returns :failure' do
        expect(decorator.uatest_status).to eq(:failure)
      end
    end

    context 'when User Acceptance Tests are missing' do
      let(:uatest) { nil }

      it 'returns nil' do
        expect(decorator.uatest_status).to be nil
      end
    end
  end

  describe '#summary_status' do
    context 'when status of deploys, builds, and QA submission are success' do
      let(:builds) { { 'frontend' => Build.new(success: true) } }
      let(:deploys) { [Deploy.new(correct: true)] }
      let(:qa_submission) { QaSubmission.new(accepted: true) }

      it 'returns :success' do
        expect(decorator.summary_status).to eq(:success)
      end
    end

    context 'when any status of deploys, builds, or QA submission is failed' do
      let(:builds) { { 'frontend' => Build.new(success: true) } }
      let(:deploys) { [Deploy.new(correct: true)] }
      let(:qa_submission) { QaSubmission.new(accepted: false) }

      it 'returns :failure' do
        expect(decorator.summary_status).to eq(:failure)
      end
    end

    context 'when no status is a failure but at least one is a warning' do
      let(:builds) { { 'frontend' => Build.new } }
      let(:deploys) { [Deploy.new(correct: true)] }
      let(:qa_submission) { QaSubmission.new(accepted: true) }

      it 'returns nil' do
        expect(decorator.summary_status).to be(nil)
      end
    end
  end

  describe 'approval' do
    subject(:decorator) { FeatureReviewWithStatuses.new(feature_review, tickets: tickets) }

    describe 'approved_at' do
      let(:approval_time) { Time.current }
      let(:tickets) {
        [
          Ticket.new(approved_at: approval_time),
          Ticket.new(approved_at: approval_time - 1.hour),
        ]
      }

      context 'when feature review is approved' do
        before do
          allow_any_instance_of(Ticket).to receive(:approved?).and_return(true)
        end

        it 'returns the approval time of the ticket that was approved last' do
          expect(decorator.approved_at).to eq(approval_time)
        end
      end

      context 'when feature review is not approved' do
        before do
          allow_any_instance_of(Ticket).to receive(:approved?).and_return(false)
        end

        it 'returns nil' do
          expect(decorator.approved_at).to be_nil
        end
      end
    end

    describe '#approved?' do
      subject { decorator.approved? }

      context 'when all tickets are approved' do
        let(:tickets) {
          [
            instance_double(Ticket, approved?: true),
            instance_double(Ticket, approved?: true),
          ]
        }
        it { is_expected.to be true }
      end

      context 'when some tickets are not approved' do
        let(:tickets) {
          [
            instance_double(Ticket, approved?: true),
            instance_double(Ticket, approved?: false),
          ]
        }
        it { is_expected.to be false }
      end

      context 'when there are no tickets' do
        let(:tickets) { [] }
        it { is_expected.to be false }
      end
    end

    describe '#approval_status' do
      context 'when feature review is approved' do
        let(:tickets) { [instance_double(Ticket, approved?: true)] }

        it 'returns :approved' do
          expect(decorator.approval_status).to be :approved
        end
      end

      context 'when feature review is not approved' do
        let(:tickets) { [instance_double(Ticket, approved?: false)] }

        it 'returns :not_approved' do
          expect(subject.approval_status).to be :not_approved
        end
      end
    end

    describe '#approved_path' do
      let(:feature_review) {
        instance_double(
          FeatureReview,
          base_path: '/something',
          query_hash: { 'apps' => apps, 'uat_url' => 'http://uat.com' },
          app_versions: apps,
        )
      }

      context 'feature review is approved' do
        let(:approval_time) { Time.parse('2013-09-05 14:56:52 UTC') }
        let(:tickets) {
          [
            instance_double(Ticket, approved?: true, approved_at: approval_time),
            instance_double(Ticket, approved?: true, approved_at: approval_time - 1.hour),
          ]
        }

        it 'returns the path as at the latest approval time' do
          expect(decorator.approved_path).to eq(
            '/something?apps%5Bapp1%5D=xxx&apps%5Bapp2%5D=yyy'\
            '&time=2013-09-05+14%3A56%3A52+UTC'\
            '&uat_url=http%3A%2F%2Fuat.com',
          )
        end
      end

      context 'feature review is not approved' do
        let(:tickets) { [instance_double(Ticket, approved?: false)] }

        it 'returns nil' do
          expect(subject.approved_path).to be_nil
        end
      end
    end
  end
end
