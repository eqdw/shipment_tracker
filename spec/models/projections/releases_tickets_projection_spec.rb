# require 'rails_helper'
#
# RSpec.describe Projections::ReleasesTicketsProjection do
#   let(:versions) { %w(abc def ghi) }
#
#   subject(:projection) { described_class.new(versions) }
#
#   describe '#ticket_for' do
#     let(:ticket_repository) { instance_double(Repositories::TicketRepository) }
#
#     let(:tickets) {
#       [
#         Ticket.new(key: 'JIRA-123'),
#         Ticket.new(key: 'JIRA-1'),
#         Ticket.new(key: 'JIRA-12'),
#       ]
#     }
#
#     before do
#       allow(Repositories::TicketRepository).to receive(:new).and_return(ticket_repository)
#       allow(ticket_repository).to receive(:tickets_for_versions).with(versions)
#         .and_return(tickets)
#     end
#
#     it 'returns a ticket that matches the jira key' do
#       expect(projection.ticket_for('JIRA-123')).to eq(Ticket.new(key: 'JIRA-123'))
#     end
#   end
# end
