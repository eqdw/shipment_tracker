require 'rails_helper'

RSpec.describe PullRequestUpdateJob do
  describe '#perform' do
    it "passes it's parameters to PullRequestStatus#update" do
      pr_status = instance_double(PullRequestStatus)
      params = {
        repo_url: 'http://fundingcirlce.com',
        sha: '12345',
      }
      allow(PullRequestStatus).to receive(:new).and_return(pr_status)
      expect(pr_status).to receive(:update).with(params)

      PullRequestUpdateJob.perform_now(params)
    end
  end
end
