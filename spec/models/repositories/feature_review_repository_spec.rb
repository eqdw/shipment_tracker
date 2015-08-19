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

    subject(:repository) { Repositories::FeatureReviewRepository.new(active_record_class) }

    it 'creates a snapshot for each feature review url in the event comment' do
      timestamp = DateTime.new(2015, 8, 21)

      expect(active_record_class).to receive(:create!).with(
        url: feature_review_url(frontend: 'abc', backend: 'NON1'),
        versions: %w(NON1 abc),
        event_created_at: timestamp,
      )
      expect(active_record_class).to receive(:create!).with(
        url: feature_review_url(frontend: 'NON2', backend: 'def'),
        versions: %w(def NON2),
        event_created_at: timestamp,
      )
      expect(active_record_class).to receive(:create!).with(
        url: feature_review_url(frontend: 'NON2', backend: 'NON3'),
        versions: %w(NON3 NON2),
        event_created_at: timestamp,
      )
      expect(active_record_class).to receive(:create!).with(
        url: feature_review_url(frontend: 'ghi', backend: 'NON3'),
        versions: %w(NON3 ghi),
        event_created_at: timestamp,
      )
      expect(active_record_class).to receive(:create!).with(
        url: feature_review_url(frontend: 'NON4', backend: 'NON5'),
        versions: %w(NON5 NON4),
        event_created_at: timestamp,
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
  end

  describe '#feature_reviews_for' do
    let(:attrs_a) {
      { url: feature_review_url(frontend: 'abc', backend: 'NON1'),
        versions: %w(NON1 abc),
        event_created_at: 1.day.ago }
    }
    let(:attrs_b) {
      { url: feature_review_url(frontend: 'NON2', backend: 'def'),
        versions: %w(def NON2),
        event_created_at: 3.days.ago }
    }
    let(:attrs_c) {
      { url: feature_review_url(frontend: 'NON2', backend: 'NON3'),
        versions: %w(NON3 NON2),
        event_created_at: 5.days.ago }
    }
    let(:attrs_d) {
      { url: feature_review_url(frontend: 'ghi', backend: 'NON3'),
        versions: %w(NON3 ghi),
        event_created_at: 7.days.ago }
    }
    let(:attrs_e) {
      { url: feature_review_url(frontend: 'NON4', backend: 'NON5'),
        versions: %w(NON5 NON4),
        event_created_at: 9.days.ago }
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
        expect(repository.feature_reviews_for(%w(abc def ghi))).to match_array([
          FeatureReview.new(attrs_a),
          FeatureReview.new(attrs_b),
          FeatureReview.new(attrs_d),
        ])
      end
    end

    context 'with a specified time' do
      it 'returns snapshots for the versions specified created at or before the time specified' do
        expect(repository.feature_reviews_for(%w(abc def ghi), at: 2.days.ago)).to match_array([
          FeatureReview.new(attrs_b),
          FeatureReview.new(attrs_d),
        ])
      end
    end
  end
end
