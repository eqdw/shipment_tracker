require 'rails_helper'

RSpec.describe Ticket do
  describe '#approved?' do
    it 'returns true for Done, Ready for Deployment and Deployed' do
      ['Done', 'Ready for Deployment', 'Deployed'].each do |status|
        expect(described_class.new(status: status).approved?).to eq(true)
      end
    end

    it 'returns false for any other status' do
      expect(described_class.new(status: 'any').approved?).to eq(false)
    end

    it 'returns false if status not set' do
      expect(described_class.new(status: nil).approved?).to eq(false)
    end
  end
end
