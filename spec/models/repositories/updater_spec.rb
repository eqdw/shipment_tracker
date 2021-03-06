require 'rails_helper'
require 'repositories/updater'

RSpec.describe Repositories::Updater do
  describe '.from_rails_config' do
    let(:expected_updater) { double('updater') }

    before do
      allow(Repositories::Updater).to receive(:new)
        .with(Rails.configuration.repositories)
        .and_return(expected_updater)
    end

    it 'returns a configured updater' do
      expect(Repositories::Updater.from_rails_config).to eq(expected_updater)
    end
  end

  let(:repository_1) { instance_double(Repositories::BuildRepository, 'repository_1', table_name: 'tbl_1') }
  let(:repository_2) { instance_double(Repositories::DeployRepository, 'repository_2', table_name: 'tbl_2') }
  let(:repositories) { [repository_1, repository_2] }

  let(:events) { [build(:jira_event), build(:jira_event)] }

  subject(:updater) { Repositories::Updater.new(repositories) }

  describe '#run' do
    it 'feeds events to each repository and updates the counts' do
      events.each(&:save!)

      expect(repository_1).to receive(:apply).with(events[0]).ordered
      expect(repository_1).to receive(:apply).with(events[1]).ordered

      expect(repository_2).to receive(:apply).with(events[0]).ordered
      expect(repository_2).to receive(:apply).with(events[1]).ordered

      updater.run

      last_id = events[1].id
      expect(Snapshots::EventCount.find_by(snapshot_name: repository_1.table_name).event_id).to eq(last_id)
      expect(Snapshots::EventCount.find_by(snapshot_name: repository_2.table_name).event_id).to eq(last_id)
    end

    context 'when the application is updated and we have different repositories specified' do
      let(:events) { [build(:jira_event), build(:jira_event)] }
      let(:new_events) { [build(:jira_event)] }

      it 'only feeds events that are new for each repository' do
        events.each(&:save!)

        expect(repository_1).to receive(:apply).with(events[0]).ordered
        expect(repository_1).to receive(:apply).with(events[1]).ordered

        Repositories::Updater.new([repository_1]).run

        new_events.each(&:save!)

        expect(repository_1).to receive(:apply).with(new_events[0]).ordered
        expect(repository_2).to receive(:apply).with(events[0]).ordered
        expect(repository_2).to receive(:apply).with(events[1]).ordered
        expect(repository_2).to receive(:apply).with(new_events[0]).ordered

        Repositories::Updater.new([repository_1, repository_2]).run
      end
    end

    context 'when there are no new events' do
      let(:events) { [] }

      it 'does not update the event count' do
        expect_any_instance_of(Snapshots::EventCount).to_not receive(:save)

        updater.run
      end
    end
  end

  describe '#reset' do
    let(:events) { [build(:circle_ci_event), build(:deploy_event)] }

    let(:store_1) { Snapshots::Build }
    let(:store_2) { Snapshots::Deploy }

    let(:repository_1) { Repositories::BuildRepository.new(store_1) }
    let(:repository_2) { Repositories::DeployRepository.new(store_2) }

    it 'wipes all repositories and what events they require' do
      events.each(&:save!)

      updater.run

      expect(store_1.count).to be > 0
      expect(store_2.count).to be > 0

      updater.reset

      expect(store_1.count).to eq(0)
      expect(store_2.count).to eq(0)

      expect(repository_1).to receive(:apply).with(events[0]).ordered
      expect(repository_1).to receive(:apply).with(events[1]).ordered
      expect(repository_2).to receive(:apply).with(events[0]).ordered
      expect(repository_2).to receive(:apply).with(events[1]).ordered

      updater.run
    end
  end
end
