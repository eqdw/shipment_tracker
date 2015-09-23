require 'rails_helper'
require 'git_repository'
require 'support/git_test_repository'
require 'support/repository_builder'

RSpec.describe Queries::ReleaseQuery do
  let(:query_time) { Time.parse('2014-08-10 14:40:48 UTC') }
  let(:time_now) { Time.now }

  let(:git_diagram) {
    <<-'EOS'
        B--C----E
       /         \
 -X---A-------D---F---G-
        EOS
  }

  let(:test_git_repo) { Support::RepositoryBuilder.build(git_diagram) }
  let(:rugged_repo) { Rugged::Repository.new(test_git_repo.dir) }
  let(:git_repository) { GitRepository.new(rugged_repo) }

  let(:sha_for_X) { version_for('X') }
  let(:sha_for_A) { version_for('A') }
  let(:sha_for_B) { version_for('B') }
  let(:sha_for_C) { version_for('C') }
  let(:sha_for_D) { version_for('D') }
  let(:sha_for_E) { version_for('E') }
  let(:sha_for_F) { version_for('F') }
  let(:sha_for_G) { version_for('G') }

  let(:feature_review_for_A) {
    instance_double(
      FeatureReview,
      path: 'url_of_feature_review_for_A',
      versions: [sha_for_A],
      base_path: '/base_path_for_A',
      query_hash: { 'apps' => { 'app1' => 'A' }, 'uat_url' => 'uat.com/A' },
    )
  }

  let(:feature_review_for_C) {
    instance_double(
      FeatureReview,
      path: 'url_of_feature_review_for_C',
      versions: [sha_for_C],
      base_path: '/base_path_for_C',
      query_hash: { 'apps' => { 'app1' => 'C' }, 'uat_url' => 'uat.com/C' },
    )
  }

  let(:feature_review_for_D) {
    instance_double(
      FeatureReview,
      path: 'url_of_feature_review_for_D',
      versions: [sha_for_D],
      base_path: '/base_path_for_D',
      query_hash: { 'apps' => { 'app1' => 'D' }, 'uat_url' => 'uat.com/D' },
    )
  }

  let(:feature_review_for_E) {
    instance_double(
      FeatureReview,
      path: 'url_of_feature_review_for_E',
      versions: [sha_for_E],
      base_path: '/base_path_for_E',
      query_hash: { 'apps' => { 'app1' => 'E' }, 'uat_url' => 'uat.com/E' },
    )
  }

  let(:feature_review_for_F) {
    instance_double(
      FeatureReview,
      path: 'url_of_feature_review_for_F',
      versions: [sha_for_F],
      base_path: '/base_path_for_F',
      query_hash: { 'apps' => { 'app1' => 'F' }, 'uat_url' => 'uat.com/F' },
    )
  }

  let(:feature_review_for_G) {
    instance_double(
      FeatureReview,
      path: 'url_of_feature_review_for_G',
      versions: [sha_for_G],
      base_path: '/base_path_for_G',
    )
  }

  subject(:query) {
    described_class.new(
      release: release,
      git_repository: git_repository,
      at: query_time,
    )
  }

  let!(:feature_review_repository) { instance_double(Repositories::FeatureReviewRepository) }

  before :each do
    allow(Repositories::FeatureReviewRepository).to receive(:new)
      .and_return(feature_review_repository)
  end

  describe '#feature_reviews' do
    context 'when release is a merge commit on master branch (F)' do
      let(:release) {
        instance_double(
          Release,
          version: sha_for_F,
          commit: GitCommit.new(id: sha_for_F, parent_ids: [sha_for_D, sha_for_E]),
        )
      }

      it "returns the feature reviews for itself, and it's branch parent" do
        expect(feature_review_repository).to receive(:feature_reviews_for_versions)
          .with(
            [sha_for_F, sha_for_E],
            at: query_time,
          )
          .and_return([feature_review_for_E, feature_review_for_F, feature_review_for_G])

        expect(query.feature_reviews).to match_array([
          feature_review_for_E, feature_review_for_F
        ])
      end
    end

    context 'when release is fork commit (A)' do
      let(:release) {
        instance_double(
          Release,
          version: sha_for_A,
          commit: GitCommit.new(id: sha_for_A, parent_ids: [sha_for_X]),
        )
      }

      it 'returns feature reviews for itself' do
        expect(feature_review_repository).to receive(:feature_reviews_for_versions)
          .with(
            [sha_for_A],
            at: query_time,
          )
          .and_return([feature_review_for_A])

        expect(query.feature_reviews).to match_array([
          feature_review_for_A,
        ])
      end
    end

    context 'when release is master branch non-merge commit (D)' do
      let(:release) {
        instance_double(
          Release,
          version: sha_for_D,
          commit: GitCommit.new(id: sha_for_D, parent_ids: [sha_for_A]),
        )
      }

      it 'returns feature reviews for itself' do
        expect(feature_review_repository).to receive(:feature_reviews_for_versions)
          .with(
            [sha_for_D],
            at: query_time,
          )
          .and_return([feature_review_for_D])

        expect(query.feature_reviews).to match_array([
          feature_review_for_D,
        ])
      end
    end

    context 'when release is feature branch commit (C)' do
      # TODO: This case is no longer expected as we only show master commits on the releases page.
      # Once we refactor releases query and releases projection, this test could be dropped.
      let(:release) {
        instance_double(
          Release,
          version: sha_for_C,
          commit: GitCommit.new(id: sha_for_C, parent_ids: [sha_for_B]),
        )
      }

      it 'returns feature reviews for itself' do
        expect(feature_review_repository).to receive(:feature_reviews_for_versions)
          .with(
            [sha_for_C],
            at: query_time,
          )
          .and_return([feature_review_for_C, feature_review_for_E, feature_review_for_F])

        expect(query.feature_reviews).to match_array([
          feature_review_for_C, feature_review_for_E, feature_review_for_F
        ])
      end
    end
  end

  private

  def version_for(pretend_version)
    test_git_repo.commit_for_pretend_version(pretend_version)
  end
end
