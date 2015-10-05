require 'rails_helper'

RSpec.describe ApplicationHelper do
  describe '#commit_link' do
    let(:version) { 'abcdef123456789' }
    let(:link) { 'https://github.com/Organisation/repo' }
    let(:expected_link) { link_to('abcdef1', link + '/commit/' + version, target: '_blank') }

    it 'returns the link url with short sah' do
      expect(helper.commit_link(version, link)).to eq(expected_link)
    end
  end
end
