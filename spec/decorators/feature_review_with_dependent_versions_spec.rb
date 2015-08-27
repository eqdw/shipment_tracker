require 'rails_helper'

RSpec.describe FeatureReviewWithDependentVersions do
  let(:feature_review) {
    instance_double(
      FeatureReview,
      uat_url: 'uat_url',
      versions: %w(commitsha1 commitsha_from_other_repo),
    )
  }

  subject(:decorator) { described_class.new(feature_review) }

  it 'delegates unknown messages to the feature_review' do
    expect(decorator.uat_url).to eq(feature_review.uat_url)
    expect(decorator.versions).to eq(feature_review.versions)
  end

  describe '#dependent_versions' do
    let(:git_repository) { instance_double(GitRepository) }
    let(:commit1) { instance_double(GitCommit, id: 'commitsha1') }
    let(:commit2) { instance_double(GitCommit, id: 'commitsha2') }
    let(:commit3) { instance_double(GitCommit, id: 'commitsha3') }
    let(:commit4) { instance_double(GitCommit, id: 'commitsha4') }
    let(:commit5) { instance_double(GitCommit, id: 'commitsha5') }

    before :each do
      allow(GitRepository).to receive(:new).and_return(git_repository)
      expect(git_repository).to receive(:get_dependent_commits)
        .with('commitsha1')
        .and_return([commit3, commit4])
      expect(git_repository).to receive(:get_dependent_commits)
        .with('commitsha_from_other_repo')
        .and_return([])
    end

    it 'returns commits that depend on the feature review for approval' do
      expect(decorator.dependent_versions(git_repository)).to match_array(
        %w(commitsha1 commitsha3 commitsha4),
      )
    end
  end
end
