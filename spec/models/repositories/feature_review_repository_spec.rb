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
    let(:ticket_repository) { instance_double(Repositories::TicketRepository) }
    let(:store) { Snapshots::FeatureReview }
    let!(:time1) { 4.days.ago.change(usec: 0) }
    let!(:time2) { 3.days.ago.change(usec: 0) }
    let!(:time3) { 2.days.ago.change(usec: 0) }
    let(:git_repository_location) { class_double(GitRepositoryLocation) }
    let(:repository_location) {
      instance_double(GitRepositoryLocation, uri: 'http://github.com/owner/frontend')
    }
    let(:fr_snapshot1) {
      Snapshots::FeatureReview.create!(
        path: feature_review_path(frontend: 'abc'),
        versions: %w(abc),
        event_created_at: time1,
        approved_at: nil,
      )
    }

    let(:fr_snapshot2) {
      Snapshots::FeatureReview.create!(
        path: feature_review_path(frontend: 'def'),
        versions: %w(def),
        event_created_at: time2,
        approved_at: nil,
      )
    }

    let(:ticket1) {
      instance_double(Ticket,
        key: 'JIRA-ABC',
        paths: [fr_snapshot1.path],
        approved?: false,
                     )
    }

    let(:ticket2) {
      instance_double(Ticket,
        key: 'JIRA-XYZ',
        paths: [fr_snapshot1.path, fr_snapshot2.path],
        approved?: false,
                     )
    }

    subject(:repository) {
      Repositories::FeatureReviewRepository.new(store,
        ticket_repository: ticket_repository,
        git_repository_location: git_repository_location,
                                               )
    }

    before do
      allow(ticket_repository).to receive(:find_last_by_key)
        .with('JIRA-XYZ')
        .and_return(ticket2)
      allow(ticket_repository).to receive(:tickets_for)
        .with(feature_review_path: fr_snapshot1.path, at: time3)
        .and_return([ticket1, ticket2])
      allow(ticket_repository).to receive(:tickets_for)
        .with(feature_review_path: fr_snapshot2.path, at: time3)
        .and_return([ticket2])
      allow(PullRequestUpdateJob).to receive(:perform_later)
      allow(git_repository_location).to receive(:find_by_name)
        .with('frontend')
        .and_return(repository_location)
    end

    context 'given a comment event' do
      let(:event) {
        build(:jira_event,
          key: 'JIRA-XYZ',
          comment_body: "Reviews: http://foo.com#{fr_snapshot1.path}, http://foo.com#{fr_snapshot2.path}",
          created_at: time3,
             )
      }

      it 'creates snapshots for each feature review path in the event comment' do
        expect(store).to receive(:create!).with(
          path: fr_snapshot1.path,
          versions: fr_snapshot1.versions,
          event_created_at: event.created_at,
          approved_at: nil,
        )

        expect(store).to receive(:create!).with(
          path: fr_snapshot2.path,
          versions: fr_snapshot2.versions,
          event_created_at: event.created_at,
          approved_at: nil,
        )

        repository.apply(event)
      end
    end

    context 'when the feature review is NOT already approved' do
      let(:fr_snapshot1) {
        Snapshots::FeatureReview.create!(
          path: feature_review_path(frontend: 'abc'),
          versions: %w(abc),
          event_created_at: time1,
          approved_at: nil,
        )
      }

      context 'when the event is an approval event' do
        let(:ticket1) {
          instance_double(Ticket, key: 'JIRA-ABC', paths: [fr_snapshot1.path], approved?: true)
        }

        let(:ticket2) {
          instance_double(Ticket, key: 'JIRA-XYZ', paths: [fr_snapshot1.path], approved?: true)
        }

        let(:event) { build(:jira_event, :approved, key: 'JIRA-XYZ', created_at: time3) }

        before do
          expect(event.approval?).to be_truthy
          expect(event.unapproval?).to be_falsy
          expect(event.comment).to be_blank
        end

        it 'sets the approved_at to the created_at time for the approval event' do
          expect(store).to receive(:create!).with(
            path: fr_snapshot1.path,
            versions: fr_snapshot1.versions,
            event_created_at: event.created_at,
            approved_at: event.created_at,
          )
          repository.apply(event)
        end
      end

      context 'when the event is an unapproval event' do
        let(:ticket1) {
          instance_double(Ticket, key: 'JIRA-ABC', paths: [fr_snapshot1.path], approved?: false)
        }

        let(:ticket2) {
          instance_double(Ticket, key: 'JIRA-XYZ', paths: [fr_snapshot1.path], approved?: true)
        }

        let(:event) { build(:jira_event, :rejected, key: 'JIRA-XYZ', created_at: time3) }

        before do
          expect(event.approval?).to be_falsy
          expect(event.unapproval?).to be_truthy
          expect(event.comment).to be_blank
        end

        it 'sets the approved_at to nil' do
          expect(store).to receive(:create!).with(
            path: fr_snapshot1.path,
            versions: fr_snapshot1.versions,
            event_created_at: event.created_at,
            approved_at: nil,
          )
          repository.apply(event)
        end
      end

      context 'when the event neither approves nor unapproves the ticket' do
        context 'when the event has a comment' do
          let(:ticket1) {
            instance_double(Ticket, key: 'JIRA-ABC', paths: [fr_snapshot1.path], approved?: false)
          }

          let(:ticket2) {
            instance_double(Ticket, key: 'JIRA-XYZ', paths: [fr_snapshot1.path], approved?: true)
          }

          let(:event) {
            build(:jira_event,
              key: 'JIRA-XYZ',
              comment_body: "Reviews: http://foo.com#{fr_snapshot1.path}",
              created_at: time3,
                 )
          }

          before do
            expect(event.approval?).to be_falsy
            expect(event.unapproval?).to be_falsy
            expect(event.comment).to be_present
          end

          it 'sets the approved_at time to nil' do
            expect(store).to receive(:create!).with(
              path: fr_snapshot1.path,
              versions: fr_snapshot1.versions,
              event_created_at: event.created_at,
              approved_at: nil,
            )

            repository.apply(event)
          end
        end

        context 'when the event has no comment' do
          let(:event) { build(:jira_event, key: 'JIRA-XYZ', created_at: time3) }

          before do
            expect(event.approval?).to be_falsy
            expect(event.unapproval?).to be_falsy
            expect(event.comment).to be_blank
          end

          it 'does NOT create a new snapshot' do
            expect(store).not_to receive(:create!)
            repository.apply(event)
          end
        end
      end
    end

    context 'when the feature review is ALREADY approved' do
      let(:fr_snapshot1) {
        Snapshots::FeatureReview.create!(
          path: feature_review_path(frontend: 'abc'),
          versions: %w(abc),
          event_created_at: time1,
          approved_at: time2,
        )
      }

      context 'when the event is an approval event' do
        let(:ticket1) {
          instance_double(Ticket, key: 'JIRA-ABC', paths: [fr_snapshot1.path], approved?: true)
        }

        let(:ticket2) {
          instance_double(Ticket, key: 'JIRA-XYZ', paths: [fr_snapshot1.path], approved?: true)
        }

        let(:event) { build(:jira_event, :approved, key: 'JIRA-XYZ', created_at: time3) }

        before do
          expect(event.approval?).to be_truthy
          expect(event.unapproval?).to be_falsy
          expect(event.comment).to be_blank
        end

        it 'reuses the approved_at time from the last snapshot' do
          expect(store).to receive(:create!).with(
            path: fr_snapshot1.path,
            versions: fr_snapshot1.versions,
            event_created_at: event.created_at,
            approved_at: fr_snapshot1.approved_at,
          )
          repository.apply(event)
        end
      end

      context 'when the event is an unapproval event' do
        let(:ticket1) {
          instance_double(Ticket, key: 'JIRA-ABC', paths: [fr_snapshot1.path], approved?: true)
        }

        let(:ticket2) {
          instance_double(Ticket, key: 'JIRA-XYZ', paths: [fr_snapshot1.path], approved?: false)
        }

        let(:event) { build(:jira_event, :rejected, key: 'JIRA-XYZ', created_at: time3) }

        before do
          expect(event.approval?).to be_falsy
          expect(event.unapproval?).to be_truthy
          expect(event.comment).to be_blank
        end

        it 'sets the approved_at to nil' do
          expect(store).to receive(:create!).with(
            path: fr_snapshot1.path,
            versions: fr_snapshot1.versions,
            event_created_at: event.created_at,
            approved_at: nil,
          )
          repository.apply(event)
        end
      end

      context 'when the event neither approves nor unapproves the ticket' do
        context 'when the event has a comment' do
          let(:ticket1) {
            instance_double(Ticket, key: 'JIRA-ABC', paths: [fr_snapshot1.path], approved?: true)
          }

          let(:ticket2) {
            instance_double(Ticket, key: 'JIRA-XYZ', paths: [fr_snapshot1.path], approved?: true)
          }

          let(:event) {
            build(:jira_event,
              key: 'JIRA-XYZ',
              comment_body: "Reviews: http://foo.com#{fr_snapshot1.path}",
              created_at: time3,
                 )
          }

          before do
            expect(event.approval?).to be_falsy
            expect(event.unapproval?).to be_falsy
            expect(event.comment).to be_present
          end

          it 'reuses the approved_at time from the last snapshot' do
            expect(store).to receive(:create!).with(
              path: fr_snapshot1.path,
              versions: fr_snapshot1.versions,
              event_created_at: event.created_at,
              approved_at: fr_snapshot1.approved_at,
            )
            repository.apply(event)
          end
        end

        context 'when the event has no comment' do
          let(:event) { build(:jira_event, key: 'JIRA-XYZ', created_at: time3) }

          before do
            expect(event.approval?).to be_falsy
            expect(event.unapproval?).to be_falsy
            expect(event.comment).to be_blank
          end

          it 'does NOT create a new snapshot' do
            expect(store).not_to receive(:create!)
            repository.apply(event)
          end
        end
      end
    end

    describe 'updating Github pull requests' do
      context 'given a comment event' do
        let(:event) {
          build(:jira_event,
            key: 'JIRA-XYZ',
            comment_body: "Reviews: http://foo.com#{fr_snapshot1.path}, http://foo.com#{fr_snapshot2.path}",
            created_at: time3,
               )
        }

        it 'schedules an update to the pull request for each version' do
          expect(PullRequestUpdateJob).to receive(:perform_later).with(
            repo_url: 'http://github.com/owner/frontend',
            sha: 'abc',
          )
          expect(PullRequestUpdateJob).to receive(:perform_later).with(
            repo_url: 'http://github.com/owner/frontend',
            sha: 'def',
          )
          repository.apply(event)
        end
      end

      context 'given an approval event' do
        let(:event) {
          build(:jira_event, :approved, key: 'JIRA-XYZ', created_at: time3)
        }

        it 'schedules an update to the pull request for each version' do
          expect(PullRequestUpdateJob).to receive(:perform_later).with(
            repo_url: 'http://github.com/owner/frontend',
            sha: 'abc',
          )
          expect(PullRequestUpdateJob).to receive(:perform_later).with(
            repo_url: 'http://github.com/owner/frontend',
            sha: 'def',
          )
          repository.apply(event)
        end
      end

      context 'given an unaproval event' do
        let(:event) {
          build(:jira_event, :rejected, key: 'JIRA-XYZ', created_at: time3)
        }

        it 'schedules an update to the pull request for each version' do
          expect(PullRequestUpdateJob).to receive(:perform_later).with(
            repo_url: 'http://github.com/owner/frontend',
            sha: 'abc',
          )
          expect(PullRequestUpdateJob).to receive(:perform_later).with(
            repo_url: 'http://github.com/owner/frontend',
            sha: 'def',
          )
          repository.apply(event)
        end
      end

      context 'given another event' do
        let(:event) {
          build(:jira_event, key: 'JIRA-XYZ', created_at: time3)
        }

        it 'does not schedule an update to the pull request for each version' do
          expect(PullRequestUpdateJob).not_to receive(:perform_later)
          repository.apply(event)
        end
      end

      context 'given repository location can not be found' do
        let(:event) {
          build(:jira_event,
            key: 'JIRA-XYZ',
            comment_body: "Reviews: http://foo.com#{fr_snapshot1.path}, http://foo.com#{fr_snapshot2.path}",
            created_at: time3,
               )
        }

        before do
          allow(git_repository_location).to receive(:find_by_name).with('frontend').and_return(nil)
        end

        it 'does not schedule an update to the pull request' do
          expect(PullRequestUpdateJob).to_not receive(:perform_later)
          repository.apply(event)
        end
      end
    end
  end

  describe '#feature_review_for_path' do
    let!(:attrs_1) {
      {
        path: feature_review_path(frontend: 'abc'),
        versions: %w(abc),
        event_created_at: 7.day.ago,
        approved_at: nil,
      }
    }

    let!(:attrs_2) {
      {
        path: feature_review_path(frontend: 'def'),
        versions: %w(def),
        event_created_at: 5.days.ago,
        approved_at: nil,
      }
    }

    let!(:attrs_3) {
      {
        path: feature_review_path(frontend: 'abc'),
        versions: %w(abc),
        event_created_at: 3.days.ago,
        approved_at: nil,
      }
    }

    let!(:attrs_4) {
      {
        path: feature_review_path(frontend: 'ghi'),
        versions: %w(ghi),
        event_created_at: 1.days.ago,
        approved_at: nil,
      }
    }

    before :each do
      Snapshots::FeatureReview.create!(attrs_1)
      Snapshots::FeatureReview.create!(attrs_2)
      Snapshots::FeatureReview.create!(attrs_3)
      Snapshots::FeatureReview.create!(attrs_4)
    end

    context 'with unspecified time' do
      it 'returns the latest snapshot for the given path' do
        path = feature_review_path(frontend: 'abc')
        expect(repository.feature_review_for_path(path)).to eq(FeatureReview.new(attrs_3))
      end
    end

    context 'with a specified time' do
      it 'returns the latest snapshot for the given path at or before the specified time' do
        path = feature_review_path(frontend: 'abc')
        expect(repository.feature_review_for_path(path, at: 4.days.ago)).to eq(FeatureReview.new(attrs_1))
      end
    end
  end

  describe '#feature_reviews_for_versions' do
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
        expect(repository.feature_reviews_for_versions(%w(abc def ghi))).to match_array([
          FeatureReview.new(attrs_a),
          FeatureReview.new(attrs_b),
          FeatureReview.new(attrs_d),
        ])
      end
    end

    context 'with a specified time' do
      it 'returns snapshots for the versions specified created at or before the time specified' do
        expect(repository.feature_reviews_for_versions(%w(abc def ghi), at: 3.days.ago)).to match_array([
          FeatureReview.new(attrs_b),
          FeatureReview.new(attrs_d),
        ])
      end
    end
  end
end
