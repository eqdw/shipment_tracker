require 'rails_helper'
require 'repositories/feature_review_repository'

RSpec.describe Repositories::FeatureReviewRepository do
  subject(:repository) { Repositories::FeatureReviewRepository.new }

  describe '#table_name' do
    let(:store) { class_double(Snapshots::FeatureReview, table_name: 'the_table_name') }

    subject(:repository) { Repositories::FeatureReviewRepository.new(store) }

    it 'delegates to the active record class backing the repository' do
      expect(repository.table_name).to eq('the_table_name')
    end
  end

  describe '#apply' do
    subject(:repository) { Repositories::FeatureReviewRepository.new(store, ticket_store: ticket_store) }

    describe 'creating snapshots' do
      let(:store) { class_double(Snapshots::FeatureReview) }
      let(:ticket_store) { class_double(Snapshots::Ticket) }
      let(:timestamp) { Time.parse('2014-08-21 00:00:00 UTC') }

      let(:params1) { { frontend: 'abc', backend: 'NON1' } }
      let(:params2) { { frontend: 'NON2', backend: 'def' } }
      let(:params3) { { frontend: 'NON2', backend: 'NON3' } }
      let(:params4) { { frontend: 'ghi', backend: 'NON3' } }
      let(:params5) { { frontend: 'NON4', backend: 'NON5' } }

      let(:review_path1) { feature_review_path(params1) }
      let(:review_path2) { feature_review_path(params2) }
      let(:review_path3) { feature_review_path(params3) }
      let(:review_path4) { feature_review_path(params4) }
      let(:review_path5) { feature_review_path(params5) }

      let(:last_ticket1) { instance_double(Snapshots::Ticket, paths: [review_path1]) }
      let(:last_ticket2) { instance_double(Snapshots::Ticket, paths: [review_path2]) }
      let(:last_ticket3) { instance_double(Snapshots::Ticket, paths: [review_path3]) }
      let(:last_ticket4) { instance_double(Snapshots::Ticket, paths: [review_path4, review_path5]) }

      before :each do
        allow(store).to receive(:most_recent_snapshot).and_return(nil)
        allow(ticket_store).to receive(:most_recent_snapshot).and_return(
          last_ticket1, last_ticket2, last_ticket3, last_ticket4
        )
      end

      it 'creates a snapshot for each feature review path in the event comment' do
        expect(store).to receive(:create!).with(
          path: review_path1,
          versions: %w(NON1 abc),
          event_created_at: timestamp,
          approved_at: nil,
        )
        expect(store).to receive(:create!).with(
          path: review_path2,
          versions: %w(def NON2),
          event_created_at: timestamp,
          approved_at: nil,
        )
        expect(store).to receive(:create!).with(
          path: review_path3,
          versions: %w(NON3 NON2),
          event_created_at: timestamp,
          approved_at: nil,
        )
        expect(store).to receive(:create!).with(
          path: review_path4,
          versions: %w(NON3 ghi),
          event_created_at: timestamp,
          approved_at: nil,
        )
        expect(store).to receive(:create!).with(
          path: review_path5,
          versions: %w(NON5 NON4),
          event_created_at: timestamp,
          approved_at: nil,
        )

        [
          build(:jira_event,
            comment_body: "Review: #{feature_review_url(params1)}",
            created_at: timestamp),
          build(:jira_event,
            comment_body: "Review: #{feature_review_url(params2)}",
            created_at: timestamp),
          build(:jira_event,
            comment_body: "Review: #{feature_review_url(params3)}",
            created_at: timestamp),
          build(:jira_event,
            comment_body: "Review: #{feature_review_url(params4)} and: #{feature_review_url(params5)}",
            created_at: timestamp),
        ].each do |event|
          repository.apply(event)
        end
      end
    end

    describe 'approved_at' do
      let(:event_created_times) { [3.days.ago, 2.days.ago] }

      let(:store) { class_double(Snapshots::FeatureReview, most_recent_snapshot: last_snapshot) }
      let(:ticket_store) { class_double(Snapshots::Ticket, most_recent_snapshot: last_ticket) }

      let(:review_path) { feature_review_path(frontend: 'abc') }
      let(:last_ticket) { instance_double(Snapshots::Ticket, paths: [review_path]) }

      before :each do
        allow(store).to receive(:where).and_return(store)
        allow(store).to receive(:order).and_return([last_snapshot])
      end

      subject(:repository) { Repositories::FeatureReviewRepository.new(store, ticket_store: ticket_store) }

      context 'when the feature review is NOT approved' do
        let(:last_snapshot) {
          Snapshots::FeatureReview.create!(
            path: feature_review_path(frontend: 'abc'),
            versions: %w(abc),
            event_created_at: event_created_times.first,
            approved_at: nil,
          )
        }

        context 'when the event is an approval event' do
          it 'sets the approved_at to the created_at time for the approval event' do
            allow_any_instance_of(FeatureReviewWithStatuses).to receive(:approved?).and_return(true, false)

            expect(store).to receive(:create!).with(
              path: review_path,
              versions: %w(abc),
              event_created_at: event_created_times.last,
              approved_at: event_created_times.last,
            )

            repository.apply(build(:jira_event, :approved, created_at: event_created_times.last))
          end
        end

        context 'when the event is an unapproval event' do
          it 'sets the approved_at to nil' do
            allow_any_instance_of(FeatureReviewWithStatuses).to receive(:approved?).and_return(false, false)

            expect(store).to receive(:create!).with(
              path: review_path,
              versions: %w(abc),
              event_created_at: event_created_times.last,
              approved_at: nil,
            )

            repository.apply(build(:jira_event, :rejected, created_at: event_created_times.last))
          end
        end

        context 'when the event neither approves nor unapproves the ticket' do
          it 'reuses the approved_at time from the last snapshot' do
            allow_any_instance_of(FeatureReviewWithStatuses).to receive(:approved?).and_return(false, false)

            expect(store).to receive(:create!).with(
              path: review_path,
              versions: %w(abc),
              event_created_at: event_created_times.last,
              approved_at: last_snapshot.approved_at,
            )

            repository.apply(build(:jira_event, created_at: event_created_times.last))
          end
        end
      end

      context 'when the feature review is approved' do
        let(:last_snapshot) {
          Snapshots::FeatureReview.create!(
            path: review_path,
            versions: %w(abc),
            event_created_at: event_created_times.first,
            approved_at: event_created_times.first,
          )
        }

        context 'when the event is an approval event' do
          it 'sets the approved_at to the created at time for the first approval event' do
            allow_any_instance_of(FeatureReviewWithStatuses).to receive(:approved?).and_return(true, true)

            expect(store).to receive(:create!).with(
              path: review_path,
              versions: %w(abc),
              event_created_at: event_created_times.last,
              approved_at: last_snapshot.approved_at,
            )

            repository.apply(build(:jira_event, :approved, created_at: event_created_times.last))
          end
        end

        context 'when the event is an unapproval event' do
          it 'sets the approved_at to nil' do
            allow_any_instance_of(FeatureReviewWithStatuses).to receive(:approved?).and_return(false, true)

            expect(store).to receive(:create!).with(
              path: review_path,
              versions: %w(abc),
              event_created_at: event_created_times.last,
              approved_at: nil,
            )

            repository.apply(build(:jira_event, :rejected, created_at: event_created_times.last))
          end
        end

        context 'when the event neither approves nor unapproves the ticket' do
          it 'reuses the approved_at time from the last snapshot' do
            allow_any_instance_of(FeatureReviewWithStatuses).to receive(:approved?).and_return(true, true)

            expect(store).to receive(:create!).with(
              path: review_path,
              versions: %w(abc),
              event_created_at: event_created_times.last,
              approved_at: last_snapshot.approved_at,
            )

            repository.apply(build(:jira_event, created_at: event_created_times.last))
          end
        end
      end
    end
  end

  describe '#feature_reviews_for' do
    let(:attrs_a) {
      { path: feature_review_path(frontend: 'abc', backend: 'NON1'),
        versions: %w(NON1 abc),
        event_created_at: 1.day.ago,
        approved_at: nil }
    }
    let(:attrs_b) {
      { path: feature_review_path(frontend: 'NON2', backend: 'def'),
        versions: %w(def NON2),
        event_created_at: 3.days.ago,
        approved_at: nil  }
    }
    let(:attrs_c) {
      { path: feature_review_path(frontend: 'NON2', backend: 'NON3'),
        versions: %w(NON3 NON2),
        event_created_at: 5.days.ago,
        approved_at: nil  }
    }
    let(:attrs_d) {
      { path: feature_review_path(frontend: 'ghi', backend: 'NON3'),
        versions: %w(NON3 ghi),
        event_created_at: 7.days.ago,
        approved_at: nil  }
    }
    let(:attrs_e) {
      { path: feature_review_path(frontend: 'NON4', backend: 'NON5'),
        versions: %w(NON5 NON4),
        event_created_at: 9.days.ago,
        approved_at: nil  }
    }

    before :each do
      Snapshots::FeatureReview.create!(attrs_a)
      Snapshots::FeatureReview.create!(attrs_b)
      Snapshots::FeatureReview.create!(attrs_c)
      Snapshots::FeatureReview.create!(attrs_d)
      Snapshots::FeatureReview.create!(attrs_e)
    end

    context 'with unspecified time' do
      it 'returns the latest snapshots for the versions specified' do
        expect(repository.feature_reviews_for(versions: %w(abc def ghi))).to match_array([
          FeatureReview.new(attrs_a),
          FeatureReview.new(attrs_b),
          FeatureReview.new(attrs_d),
        ])
      end
    end

    context 'with a specified time' do
      it 'returns snapshots for the versions specified created at or before the time specified' do
        expect(repository.feature_reviews_for(versions: %w(abc def ghi), at: 2.days.ago)).to match_array([
          FeatureReview.new(attrs_b),
          FeatureReview.new(attrs_d),
        ])
      end
    end
  end
end
