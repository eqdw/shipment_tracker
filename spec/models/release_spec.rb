require 'rails_helper'

RSpec.describe Release do
  describe '#version' do
    let(:commit) { GitCommit.new(id: 'abc') }
    subject(:release) { described_class.new(commit: commit) }

    it 'returns the commit id' do
      expect(release.version).to eq('abc')
    end
  end
end
