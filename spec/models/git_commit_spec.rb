require 'rails_helper'

RSpec.describe GitCommit do
  describe '#subject_line' do
    subject(:subject_line) {
      described_class.new(message: "subject\n\nlorem ipsum dolor sit amet").subject_line
    }

    it 'returns the first line of the message' do
      expect(subject_line).to eq('subject')
    end
  end

  describe '#associated_ids' do
    subject(:associated_ids) { described_class.new(id: id, parent_ids: parent_ids).associated_ids }
    let(:parent_ids) { [first_parent_id, second_parent_id].compact }
    let(:first_parent_id) { '789' }
    let(:id) { '123' }

    context 'when commit is a merge commit (i.e. has a second parent)' do
      let(:second_parent_id) { '456' }

      it 'returns an array id and id of second parent' do
        expect(associated_ids).to match_array([id, second_parent_id])
      end
    end

    context 'when commit is not a merge commit (i.e. has no second parent)' do
      let(:second_parent_id) { nil }

      it 'return array with id' do
        expect(associated_ids).to eq([id])
      end
    end

    context 'when commit has no parent_ids' do
      let(:first_parent_id) { nil }
      let(:second_parent_id) { nil }

      it 'return array with id' do
        expect(associated_ids).to eq([id])
      end
    end
  end
end
