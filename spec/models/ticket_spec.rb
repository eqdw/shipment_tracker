require 'rails_helper'

RSpec.describe Ticket do
  describe '#approved?' do
    it 'returns true for approved statuses' do
      Rails.application.config.approved_statuses.each do |status|
        expect(Ticket.new(status: status).approved?).to be true
      end
    end

    it 'returns false for any other status' do
      expect(Ticket.new(status: 'any').approved?).to be false
    end

    it 'returns false if status not set' do
      expect(Ticket.new(status: nil).approved?).to be false
    end
  end
end
