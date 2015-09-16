require 'rails_helper'

RSpec.describe FeatureReviewWithStatuses do
  let(:tickets) { [] }
  let(:builds) { {} }
  let(:deploys) { [] }
  let(:qa_submission) { nil }
  let(:uatest) { nil }
  let(:apps) { {} }
  let(:uat_url) { 'http://uat.com' }

  let(:feature_review) {
    instance_double(
      FeatureReview,
      uat_url: uat_url,
      app_versions: apps,
    )
  }

  let(:feature_review_query) {
    instance_double(
      Queries::FeatureReviewQuery,
      tickets: tickets,
      builds: builds,
      deploys: deploys,
      qa_submission: qa_submission,
      uatest: uatest,
    )
  }

  let(:query_time) { Time.parse('2014-08-10 14:40:48 UTC') }
  let(:time_now) { Time.now }

  let(:query_class) { class_double(Queries::FeatureReviewQuery, new: feature_review_query) }

  let(:decorator) { described_class.new(feature_review, at: query_time, query_class: query_class) }

  it 'delegates #apps, #tickets, #builds, #deploys and #qa_submission to the feature_review_query' do
    expect(decorator.tickets).to eq(feature_review_query.tickets)
    expect(decorator.builds).to eq(feature_review_query.builds)
    expect(decorator.deploys).to eq(feature_review_query.deploys)
    expect(decorator.qa_submission).to eq(feature_review_query.qa_submission)
    expect(decorator.uatest).to eq(feature_review_query.uatest)
  end

  it 'delegates unknown messages to the feature_review' do
    expect(decorator.uat_url).to eq(feature_review.uat_url)
  end

  describe '#time' do
    context 'when initialized with a time' do
      it 'returns the time it was initialized with' do
        expect(decorator.time).to eq(query_time)
      end
    end

    context 'when NOT initialized with a time' do
      it 'returns the time when it was initialized' do
        Timecop.freeze(time_now) do
          decorator_without_specific_time = described_class.new(feature_review)
          expect(decorator_without_specific_time.time).to eq(time_now)
        end
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

  describe '#approved?' do
    context 'when all tickets are approved' do
      let(:tickets) {
        [instance_double(Ticket, approved?: true),
         instance_double(Ticket, approved?: true)]
      }

      it 'is true' do
        expect(decorator.approved?).to be true
      end
    end

    context 'when no tickets are approved' do
      let(:tickets) {
        [instance_double(Ticket, approved?: false),
         instance_double(Ticket, approved?: false)]
      }

      it 'is false' do
        expect(decorator.approved?).to eq(false)
      end
    end

    context 'when some tickets are approved' do
      let(:tickets) {
        [instance_double(Ticket, approved?: true),
         instance_double(Ticket, approved?: false)]
      }

      it 'is false' do
        expect(decorator.approved?).to eq(false)
      end
    end

    context 'when there are no tickets' do
      let(:tickets) { [] }

      it 'is false' do
        expect(decorator.approved?).to eq(false)
      end
    end
  end

  describe '#approval_status' do
    context 'when feature review is approved' do
      it 'is :approved' do
        allow(decorator).to receive(:approved?).and_return(true)
        expect(decorator.approval_status).to eq(:approved)
      end
    end

    context 'when no feature review is NOT approved' do
      it 'is :unapproved' do
        allow(decorator).to receive(:approved?).and_return(false)
        expect(decorator.approval_status).to eq(:unapproved)
      end
    end
  end

  describe '#path_with_query_time' do
    let(:base_path) { '/feature_reviews' }
    let(:feature_review) {
      instance_double(FeatureReview,
        base_path: base_path,
        query_hash: {
          'apps' => { 'app1' => 'xxx', 'app2' => 'yyy' },
          'uat_url' => 'uat.com',
        })
    }

    it 'returns the path for the feature review at the query time' do
      query = '?apps%5Bapp1%5D=xxx&apps%5Bapp2%5D=yyy&time=2014-08-10+14%3A40%3A48+UTC&uat_url=uat.com'
      expect(decorator.path_with_query_time).to eq("#{base_path}#{query}")
    end
  end

  describe '#approved_path' do
    let(:base_path) { '/feature_reviews' }
    let(:query_hash) {
      { 'apps' => { 'app1' => 'xxx' }, 'uat_url' => 'uat.com' }
    }

    context 'when the feature review is approved' do
      let(:feature_review) {
        instance_double(FeatureReview,
          uat_url: 'uat.com',
          versions: 'xxx',
          approved_at: Time.parse('2014-04-23 11:36:32 UTC'),
          base_path: base_path,
          query_hash: query_hash)
      }

      before :each do
        allow(decorator).to receive(:approved?).and_return(true)
      end

      it 'returns the path for the feature review at the approved_at time' do
        query = '?apps%5Bapp1%5D=xxx&time=2014-04-23+11%3A36%3A32+UTC&uat_url=uat.com'
        expect(decorator.approved_path).to eq("#{base_path}#{query}")
      end

      context 'when the feature review does not have an approval time' do
        let(:feature_review) { instance_double(FeatureReview, approved_at: nil) }

        it 'returns nil' do
          expect(decorator.approved_path).to be_nil
        end
      end
    end

    context 'when the feature review is NOT approved' do
      let(:feature_review) {
        instance_double(FeatureReview,
          uat_url: 'uat.com',
          versions: 'xxx',
          approved_at: Time.parse('2014-04-23 11:36:32 UTC'),
          base_path: base_path,
          query_hash: query_hash)
      }

      before :each do
        allow(decorator).to receive(:approved?).and_return(false)
      end

      it 'returns nil' do
        expect(decorator.approved_path).to be_nil
      end
    end
  end
end
