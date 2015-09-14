require 'rails_helper'
require 'repositories/feature_review_repository'

RSpec.describe Repositories::FeatureReviewRepository do
  subject(:repository) { Repositories::FeatureReviewRepository.new }

  describe '#table_name' do
    let(:active_record_class) { class_double(Snapshots::FeatureReview, table_name: 'the_table_name') }

    subject(:repository) { Repositories::FeatureReviewRepository.new(active_record_class) }

    it 'delegates to the active record class backing the repository' do
      expect(repository.table_name).to eq('the_table_name')
    end
  end

  describe '#apply' do
    let(:active_record_class) { class_double(Snapshots::FeatureReview) }
    let(:timestamp) { Time.parse('2014-08-21 00:00:00 UTC') }

    before :each do
      allow(active_record_class).to receive(:where).and_return(active_record_class)
      allow(active_record_class).to receive(:order).and_return([last_snapshot])
    end

    let(:last_snapshot) {
      Snapshots::FeatureReview.create!(
        url: feature_review_url(frontend: 'abc'),
        versions: %w(abc),
        event_created_at: timestamp - 2.days,
        approved_at: Time.parse('2014-09-19 00:00:00 UTC'),
      )
    }

    subject(:repository) { Repositories::FeatureReviewRepository.new(active_record_class) }

    it 'creates a snapshot for each feature review url in the event comment' do
      expect(active_record_class).to receive(:create!).with(
        url: feature_review_url(frontend: 'abc', backend: 'NON1'),
        versions: %w(NON1 abc),
        event_created_at: timestamp,
        approved_at: nil,
      )
      expect(active_record_class).to receive(:create!).with(
        url: feature_review_url(frontend: 'NON2', backend: 'def'),
        versions: %w(def NON2),
        event_created_at: timestamp,
        approved_at: nil,
      )
      expect(active_record_class).to receive(:create!).with(
        url: feature_review_url(frontend: 'NON2', backend: 'NON3'),
        versions: %w(NON3 NON2),
        event_created_at: timestamp,
        approved_at: nil,
      )
      expect(active_record_class).to receive(:create!).with(
        url: feature_review_url(frontend: 'ghi', backend: 'NON3'),
        versions: %w(NON3 ghi),
        event_created_at: timestamp,
        approved_at: nil,
      )
      expect(active_record_class).to receive(:create!).with(
        url: feature_review_url(frontend: 'NON4', backend: 'NON5'),
        versions: %w(NON5 NON4),
        event_created_at: timestamp,
        approved_at: nil,
      )

      [
        build(:jira_event,
          comment_body: "Review: #{feature_review_url(frontend: 'abc', backend: 'NON1')}",
          created_at: timestamp),
        build(:jira_event,
          comment_body: "Review: #{feature_review_url(frontend: 'NON2', backend: 'def')}",
          created_at: timestamp),
        build(:jira_event,
          comment_body: "Review: #{feature_review_url(frontend: 'NON2', backend: 'NON3')}",
          created_at: timestamp),
        build(:jira_event,
          comment_body: "Review: #{feature_review_url(frontend: 'ghi', backend: 'NON3')} "\
                        "and: #{feature_review_url(frontend: 'NON4', backend: 'NON5')}",
          created_at: timestamp),
      ].each do |event|
        repository.apply(event)
      end
    end

    context 'when the feature is approved,' do
      before :each do
        allow_any_instance_of(FeatureReviewWithStatuses).to receive(:approved?).and_return(true)
      end

      context 'when the approved_at time is set on the last snapshot,' do
        it 'reuses the approved_at time from the last snapshot' do
          expect(active_record_class).to receive(:create!).with(
            url: feature_review_url(frontend: 'abc'),
            versions: %w(abc),
            event_created_at: timestamp,
            approved_at: last_snapshot.approved_at,
          )

          repository.apply(build(:jira_event, :approved,
            comment_body: "Review: #{feature_review_url(frontend: 'abc')}",
            created_at: timestamp))
        end
      end

      context 'when the approved_at time is NOT set on the last snapshot,' do
        before :each do
          last_snapshot.update_attributes!(approved_at: nil)
        end

        it 'sets the approved_at time to the event_created_at time' do
          expect(active_record_class).to receive(:create!).with(
            url: feature_review_url(frontend: 'abc'),
            versions: %w(abc),
            event_created_at: timestamp,
            approved_at: timestamp,
          )

          repository.apply(build(:jira_event, :approved,
            comment_body: "Review: #{feature_review_url(frontend: 'abc')}",
            created_at: timestamp))
        end
      end

      context 'when there is no previous snapshot,' do
        before :each do
          allow(active_record_class).to receive(:where).and_return(active_record_class)
          allow(active_record_class).to receive(:order).and_return([])
        end

        it 'sets the approved_at time to the event_created_at time' do
          expect(active_record_class).to receive(:create!).with(
            url: feature_review_url(frontend: 'abc'),
            versions: %w(abc),
            event_created_at: timestamp,
            approved_at: timestamp,
          )

          repository.apply(build(:jira_event, :approved,
            comment_body: "Review: #{feature_review_url(frontend: 'abc')}",
            created_at: timestamp))
        end
      end
    end

    context 'when the feature is NOT approved,' do
      before :each do
        allow_any_instance_of(FeatureReviewWithStatuses).to receive(:approved?).and_return(false)
      end

      it 'nullifies the approved_at' do
        expect(active_record_class).to receive(:create!).with(
          url: feature_review_url(frontend: 'abc'),
          versions: %w(abc),
          event_created_at: timestamp,
          approved_at: nil,
        )

        repository.apply(build(:jira_event, :rejected,
          comment_body: "Review: #{feature_review_url(frontend: 'abc')}",
          created_at: timestamp))
      end
    end
  end

  describe '#feature_reviews_for' do
    let(:attrs_a) {
      { url: feature_review_url(frontend: 'abc', backend: 'NON1'),
        versions: %w(NON1 abc),
        event_created_at: 1.day.ago,
        approved_at: nil }
    }
    let(:attrs_b) {
      { url: feature_review_url(frontend: 'NON2', backend: 'def'),
        versions: %w(def NON2),
        event_created_at: 3.days.ago,
        approved_at: nil  }
    }
    let(:attrs_c) {
      { url: feature_review_url(frontend: 'NON2', backend: 'NON3'),
        versions: %w(NON3 NON2),
        event_created_at: 5.days.ago,
        approved_at: nil  }
    }
    let(:attrs_d) {
      { url: feature_review_url(frontend: 'ghi', backend: 'NON3'),
        versions: %w(NON3 ghi),
        event_created_at: 7.days.ago,
        approved_at: nil  }
    }
    let(:attrs_e) {
      { url: feature_review_url(frontend: 'NON4', backend: 'NON5'),
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
