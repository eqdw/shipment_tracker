require 'rails_helper'

RSpec.describe Repositories::TicketRepository do
  subject(:repository) { Repositories::TicketRepository.new }

  describe '#table_name' do
    let(:active_record_class) { class_double(Snapshots::Ticket, table_name: 'the_table_name') }

    subject(:repository) { Repositories::TicketRepository.new(active_record_class) }

    it 'delegates to the active record class backing the repository' do
      expect(repository.table_name).to eq('the_table_name')
    end
  end

  describe '#tickets_for_path' do
    let(:attrs_a) {
      { key: 'JIRA-A',
        summary: 'JIRA-A summary',
        status: 'Done',
        paths: [
          feature_review_path(frontend: 'NON3', backend: 'NON2'),
          feature_review_path(frontend: 'abc', backend: 'NON1'),
        ],
        event_created_at: 9.days.ago,
        versions: %w(abc NON1 NON3 NON2) }
    }

    let(:attrs_b) {
      { key: 'JIRA-B',
        summary: 'JIRA-B summary',
        status: 'Done',
        paths: [
          feature_review_path(frontend: 'def', backend: 'abc'),
          feature_review_path(frontend: 'NON3', backend: 'ghi'),
        ],
        event_created_at: 7.days.ago,
        versions: %w(def abc NON3 ghi) }
    }

    let(:attrs_c) {
      { key: 'JIRA-C',
        summary: 'JIRA-C summary',
        status: 'Done',
        paths: [feature_review_path(frontend: 'NON3', backend: 'NON2')],
        event_created_at: 5.days.ago,
        versions: %w(NON3 NON2) }
    }

    let(:attrs_d) {
      { key: 'JIRA-D',
        summary: 'JIRA-D summary',
        status: 'Done',
        paths: [feature_review_path(frontend: 'NON3', backend: 'ghi')],
        event_created_at: 3.days.ago,
        versions: %w(NON3 ghi) }
    }

    let(:attrs_e) {
      { key: 'JIRA-E',
        summary: 'JIRA-E summary',
        status: 'Done',
        paths: [feature_review_path(frontend: 'abc', backend: 'NON1')],
        event_created_at: 1.day.ago,
        versions: %w(abc NON1) }
    }

    before :each do
      Snapshots::Ticket.create!(attrs_a)
      Snapshots::Ticket.create!(attrs_b)
      Snapshots::Ticket.create!(attrs_c)
      Snapshots::Ticket.create!(attrs_d)
      Snapshots::Ticket.create!(attrs_e)
    end

    context 'with unspecified time' do
      subject {
        repository.tickets_for_path(
          feature_review_path(frontend: 'abc', backend: 'NON1'),
        )
      }

      it { is_expected.to match_array([Ticket.new(attrs_a), Ticket.new(attrs_e)]) }
    end

    context 'with a specified time' do
      subject {
        repository.tickets_for_path(
          feature_review_path(frontend: 'abc', backend: 'NON1'),
          at: 4.days.ago,
        )
      }

      it { is_expected.to match_array([Ticket.new(attrs_a)]) }
    end
  end

  describe '#apply' do
    let(:url) { feature_review_url(app: 'foo') }
    let(:path) { feature_review_path(app: 'foo') }
    let(:approval_time) { Time.current }

    it 'projects latest associated tickets' do
      jira_1 = { key: 'JIRA-1', summary: 'Ticket 1' }

      repository.apply(build(:jira_event, :created, jira_1.merge(comment_body: url)))
      results = repository.tickets_for_path(path)
      expect(results).to eq([Ticket.new(jira_1.merge(status: 'To Do', paths: [path]))])

      repository.apply(build(:jira_event, :started, jira_1))
      results = repository.tickets_for_path(path)
      expect(results).to eq([Ticket.new(jira_1.merge(status: 'In Progress', paths: [path]))])

      repository.apply(build(:jira_event, :approved, jira_1.merge(created_at: approval_time)))
      results = repository.tickets_for_path(path)
      expect(results).to eq([
        Ticket.new(jira_1.merge(status: 'Ready for Deployment', paths: [path], approved_at: approval_time)),
      ])

      repository.apply(build(:jira_event, :deployed, jira_1.merge(created_at: approval_time + 1.hour)))
      results = repository.tickets_for_path(path)
      expect(results).to eq([
        Ticket.new(jira_1.merge(status: 'Done', paths: [path], approved_at: approval_time)),
      ])

      repository.apply(build(:jira_event, :rejected, jira_1.merge(created_at: approval_time + 2.hours)))
      results = repository.tickets_for_path(path)
      expect(results).to eq([
        Ticket.new(jira_1.merge(status: 'In Progress', paths: [path], approved_at: nil)),
      ])
    end

    it 'projects the tickets referenced in JIRA comments' do
      jira_1 = { key: 'JIRA-1', summary: 'Ticket 1' }
      jira_4 = { key: 'JIRA-4', summary: 'Ticket 4' }

      [
        build(:jira_event, :created, jira_1),
        build(:jira_event, :started, jira_1),
        build(:jira_event, :development_completed, jira_1.merge(comment_body: "Review #{url}")),

        build(:jira_event, :created, key: 'JIRA-2'),
        build(
          :jira_event,
          :created,
          key: 'JIRA-3',
          comment_body: 'Review http://example.com/feature_reviews/extra/stuff',
        ),

        build(:jira_event, :created, jira_4),
        build(:jira_event, :started, jira_4),
        build(:jira_event, :development_completed, jira_4.merge(comment_body: "#{url} is ready!")),
        build(:jira_event, :deployed, jira_1.merge(created_at: approval_time)),
      ].each do |event|
        repository.apply(event)
      end

      expect(repository.tickets_for_path(path)).to match_array([
        Ticket.new(jira_1.merge(status: 'Done', paths: [path], approved_at: approval_time)),
        Ticket.new(jira_4.merge(status: 'Ready For Review', paths: [path])),
      ])
    end

    it 'ignores non JIRA issue events' do
      expect { repository.apply(build(:jira_event_user_created)) }.to_not raise_error
    end

    context 'when multiple feature reviews are referenced in the same JIRA ticket' do
      let(:url1) { feature_review_url(app1: 'one') }
      let(:url2) { feature_review_url(app2: 'two') }
      let(:path1) { feature_review_path(app1: 'one') }
      let(:path2) { feature_review_path(app2: 'two') }

      subject(:repository1) { Repositories::TicketRepository.new }
      subject(:repository2) { Repositories::TicketRepository.new }

      it 'projects the ticket referenced in the JIRA comments for each repository' do
        [
          build(:jira_event, key: 'JIRA-1', comment_body: "Review #{url1}"),
          build(:jira_event, key: 'JIRA-1', comment_body: "Review again #{url2}"),
        ].each do |event|
          repository1.apply(event)
          repository2.apply(event)
        end

        expect(
          repository1.tickets_for_path(path1),
        ).to eq([Ticket.new(key: 'JIRA-1', paths: [path1, path2])])

        expect(
          repository2.tickets_for_path(path2),
        ).to eq([Ticket.new(key: 'JIRA-1', paths: [path1, path2])])
      end
    end

    context 'with at specified' do
      it 'returns the state at that moment' do
        t = [3.hours.ago, 2.hours.ago, 1.hour.ago, 1.minute.ago]
        jira_1 = { key: 'JIRA-1', summary: 'Ticket 1' }
        jira_2 = { key: 'JIRA-2', summary: 'Ticket 2' }

        [
          build(:jira_event, :created, jira_1.merge(comment_body: url, created_at: t[0])),
          build(:jira_event, :approved, jira_1.merge(created_at: t[1])),
          build(:jira_event, :created, jira_2.merge(created_at: t[2])),
          build(:jira_event, :created, jira_2.merge(comment_body: url, created_at: t[3])),
        ].each do |event|
          repository.apply(event)
        end

        expect(repository.tickets_for_path(path, at: t[2])).to match_array([
          Ticket.new(jira_1.merge(status: 'Ready for Deployment', paths: [path], approved_at: t[1])),
        ])
      end
    end
  end

  describe '#find_last_by_key' do
    let!(:tickets) {
      [
        Snapshots::Ticket.create(key: '1', summary: 'first'),
        Snapshots::Ticket.create(key: '2', summary: 'second'),
        Snapshots::Ticket.create(key: '1', summary: 'fourth'),
        Snapshots::Ticket.create(key: '3', summary: 'third'),
      ]
    }

    context 'when key is specified' do
      it 'returns the last snapshot with that key' do
        expect(subject.find_last_by_key('1')).to eq(tickets[2])
      end
    end
  end
end
