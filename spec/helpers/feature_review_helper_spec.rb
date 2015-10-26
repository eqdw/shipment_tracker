require 'rails_helper'

RSpec.describe FeatureReviewsHelper do
  describe '#jira_link' do
    let(:jira_key) { 'JIRA-123' }
    let(:expected_link) { link_to(jira_key, 'https://jira.test/browse/JIRA-123', target: '_blank') }

    it 'returns a link to the relevant jira ticket' do
      expect(helper.jira_link(jira_key)).to eq(expected_link)
    end
  end

  describe '#edit_url' do
    let(:app_versions) { { frontend: 'abc', backend: 'def' } }
    let(:query_params) { { forms_feature_review_form: { apps: app_versions, uat_url: uat_url } } }
    let(:expected_url) { helper.new_feature_reviews_path(query_params) }

    context 'when UAT is provided' do
      let(:uat_url) { 'http://uat.com' }

      it 'returns the URL with the app versions and the UAT under review' do
        expect(helper.edit_url(app_versions, uat_url)).to eq(expected_url)
      end
    end

    context 'when UAT is not provided' do
      let(:uat_url) { nil }

      it 'returns the URL with the app versions and without a UAT' do
        expect(helper.edit_url(app_versions, uat_url)).to eq(expected_url)
      end
    end
  end
end
