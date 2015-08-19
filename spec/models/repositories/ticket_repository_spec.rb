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

  describe '#tickets_for_feature_review_urls' do
    let(:url) { 'http://foo.com/feature_reviews' }

    it 'projects latest associated tickets' do
      repository.apply(build(:jira_event, :created, key: 'JIRA-1', comment_body: url))
      results = repository.tickets_for_feature_review_urls(feature_review_url: url)
      expect(results).to eq([Ticket.new(key: 'JIRA-1', status: 'To Do', summary: '')])

      repository.apply(build(:jira_event, :started, key: 'JIRA-1'))
      results = repository.tickets_for_feature_review_urls(feature_review_url: url)
      expect(results).to eq([Ticket.new(key: 'JIRA-1', status: 'In Progress', summary: '')])
    end

    it 'projects the tickets referenced in JIRA comments' do
      jira_1 = { key: 'JIRA-1', summary: 'Ticket 1' }
      jira_4 = { key: 'JIRA-4', summary: 'Ticket 4' }

      [
        build(:jira_event, :created, jira_1),
        build(:jira_event, :started, jira_1),
        build(:jira_event, :development_completed, jira_1.merge(comment_body: "Review #{url}")),

        build(:jira_event, :created, key: 'JIRA-2'),
        build(:jira_event, :created, key: 'JIRA-3', comment_body: "Review #{url}/extra/stuff"),

        build(:jira_event, :created, jira_4),
        build(:jira_event, :started, jira_4),
        build(:jira_event, :development_completed, jira_4.merge(comment_body: "#{url} is ready!")),

        build(:jira_event, :deployed, jira_1),
      ].each do |event|
        repository.apply(event)
      end

      expect(repository.tickets_for_feature_review_urls(feature_review_url: url)).to match_array([
        Ticket.new(key: 'JIRA-1', summary: 'Ticket 1', status: 'Done'),
        Ticket.new(key: 'JIRA-4', summary: 'Ticket 4', status: 'Ready For Review'),
      ])
    end

    it 'ignores non JIRA issue events' do
      expect { repository.apply(build(:jira_event_user_created)) }.to_not raise_error
    end

    context 'when multiple feature reviews are referenced in the same JIRA ticket' do
      let(:url1) { feature_review_url(app1: 'one') }
      let(:url2) { feature_review_url(app2: 'two') }

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
          repository1.tickets_for_feature_review_urls(feature_review_url: url1),
        ).to eq([Ticket.new(key: 'JIRA-1')])

        expect(
          repository2.tickets_for_feature_review_urls(feature_review_url: url2),
        ).to eq([Ticket.new(key: 'JIRA-1')])
      end
    end

    context 'with at specified' do
      it 'returns the state at that moment' do
        t = [3.hours.ago, 2.hours.ago, 1.hour.ago, 1.minute.ago]

        [
          build(:jira_event, :created, key: 'J-1', summary: 'Job', comment_body: url, created_at: t[0]),
          build(:jira_event, :approved, key: 'J-1', summary: 'Job', created_at: t[1]),
          build(:jira_event, :created, key: 'J-2', summary: 'Job', created_at: t[2]),
          build(:jira_event, :created, key: 'J-2', summary: 'Job', comment_body: url, created_at: t[3]),
        ].each do |event|
          repository.apply(event)
        end

        expect(repository.tickets_for_feature_review_urls(feature_review_url: url, at: t[2])).to match_array([
          Ticket.new(key: 'J-1', summary: 'Job', status: 'Ready for Deployment'),
        ])
      end
    end
  end
end
