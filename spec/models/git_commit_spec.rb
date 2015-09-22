require 'rails_helper'

RSpec.describe GitCommit do
  describe '#subject_line' do
    subject(:commit) { described_class.new(message: "subject\n\nlorem ipsum dolor sit amet") }

    it 'returns the first line of the message' do
      expect(commit.subject_line).to eq('subject')
    end
  end
end
