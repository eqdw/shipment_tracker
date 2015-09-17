require 'rails_helper'
require 'snapshots/ticket'

RSpec.describe Snapshots::Ticket do
  describe '.most_recent_snapshot' do
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
        expect(Snapshots::Ticket.most_recent_snapshot('1')).to eq(tickets[2])
      end
    end

    context 'when key is not specified' do
      it 'returns the last snapshot' do
        expect(Snapshots::Ticket.most_recent_snapshot).to eq(tickets.last)
      end
    end
  end
end
