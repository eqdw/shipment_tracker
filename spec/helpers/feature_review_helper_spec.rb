require 'rails_helper'

RSpec.describe FeatureReviewsHelper do
  describe '.jira_link' do
    let(:jira_key) { 'JIRA-123' }
    let(:expected_link) { link_to(jira_key, 'https://jira.test/browse/JIRA-123', target: '_blank') }

    it 'returns the jira url for a issue key' do
      expect(helper.jira_link(jira_key)).to eq(expected_link)
    end
  end
end
