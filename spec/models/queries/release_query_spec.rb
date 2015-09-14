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
 -o---A-------D---F---G-
        EOS
  }

  let(:test_git_repo) { Support::RepositoryBuilder.build(git_diagram) }
  let(:rugged_repo) { Rugged::Repository.new(test_git_repo.dir) }
  let(:git_repository) { GitRepository.new(rugged_repo) }

  let(:sha_for_A) { version_for('A') }
  let(:sha_for_B) { version_for('B') }
  let(:sha_for_C) { version_for('C') }
  let(:sha_for_D) { version_for('D') }
  let(:sha_for_E) { version_for('E') }
  let(:sha_for_F) { version_for('F') }
  let(:sha_for_G) { version_for('G') }
  let(:base_url) { 'base_url_for_A' }
  let(:query_hash) {
    { 'apps' => { 'app1' => 'A' }, 'uat_url' => 'uat.com/A' }
  }

  let(:feature_review_for_A) {
    instance_double(
      FeatureReview,
      url: 'url_of_feature_review_for_A',
      versions: [sha_for_A],
      base_url: 'base_url_for_A',
      query_hash: { 'apps' => { 'app1' => 'A' }, 'uat_url' => 'uat.com/A' },
    )
  }

  let(:feature_review_for_B) {
    instance_double(
      FeatureReview,
      url: 'url_of_feature_review_for_B',
      versions: [sha_for_B],
      base_url: 'base_url_for_B',
      query_hash: { 'apps' => { 'app1' => 'B' }, 'uat_url' => 'uat.com/B' },
    )
  }

  let(:feature_review_for_C) {
    instance_double(
      FeatureReview,
      url: 'url_of_feature_review_for_C',
      versions: [sha_for_C],
      base_url: 'base_url_for_C',
      query_hash: { 'apps' => { 'app1' => 'C' }, 'uat_url' => 'uat.com/C' },
    )
  }

  let(:feature_review_for_D) {
    instance_double(
      FeatureReview,
      url: 'url_of_feature_review_for_D',
      versions: [sha_for_D],
      base_url: 'base_url_for_D',
      query_hash: { 'apps' => { 'app1' => 'D' }, 'uat_url' => 'uat.com/D' },
    )
  }

  let(:feature_review_for_E) {
    instance_double(
      FeatureReview,
      url: 'url_of_feature_review_for_E',
      versions: [sha_for_E],
      base_url: 'base_url_for_E',
      query_hash: { 'apps' => { 'app1' => 'E' }, 'uat_url' => 'uat.com/E' },
    )
  }

  let(:feature_review_for_F) {
    instance_double(
      FeatureReview,
      url: 'url_of_feature_review_for_F',
      versions: [sha_for_F],
      base_url: 'base_url_for_F',
      query_hash: { 'apps' => { 'app1' => 'F' }, 'uat_url' => 'uat.com/F' },
    )
  }

  let(:feature_review_for_G) {
    instance_double(
      FeatureReview,
      url: 'url_of_feature_review_for_G',
      versions: [sha_for_G],
      base_url: 'base_url_for_G',
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
      let(:release) { instance_double(Release, version: sha_for_F) }

      it "returns the feature reviews for itself, it's descendants and it's branch parent" do
        expect(feature_review_repository).to receive(:feature_reviews_for)
          .with(
            versions: [sha_for_F, sha_for_E],
            at: query_time,
          )
          .and_return([feature_review_for_E, feature_review_for_F, feature_review_for_G])

        expect(query.feature_reviews.map(&:url_with_query_time)).to match_array(%w(
          base_url_for_E?apps%5Bapp1%5D=E&time=2014-08-10+14%3A40%3A48+UTC&uat_url=uat.com%2FE
          base_url_for_F?apps%5Bapp1%5D=F&time=2014-08-10+14%3A40%3A48+UTC&uat_url=uat.com%2FF
        ))
      end
    end

    context 'when release is fork commit (A)' do
      let(:release) { instance_double(Release, version: sha_for_A) }

      it "returns feature reviews for itself and it's descendants" do
        expect(feature_review_repository).to receive(:feature_reviews_for)
          .with(
            versions: [sha_for_A],
            at: query_time,
          )
          .and_return([feature_review_for_A])

        expect(query.feature_reviews.map(&:url_with_query_time)).to match_array(%w(
          base_url_for_A?apps%5Bapp1%5D=A&time=2014-08-10+14%3A40%3A48+UTC&uat_url=uat.com%2FA
        ))
      end
    end

    context 'when release is master branch non-merge commit (D)' do
      let(:release) { instance_double(Release, version: sha_for_D) }

      it "returns feature reviews for itself and it's descendants" do
        expect(feature_review_repository).to receive(:feature_reviews_for)
          .with(
            versions: [sha_for_D],
            at: query_time,
          )
          .and_return([feature_review_for_D])

        expect(query.feature_reviews.map(&:url_with_query_time)).to match_array(%w(
          base_url_for_D?apps%5Bapp1%5D=D&time=2014-08-10+14%3A40%3A48+UTC&uat_url=uat.com%2FD
        ))
      end
    end

    context 'when release is feature branch commit (C)' do
      let(:release) { instance_double(Release, version: sha_for_C) }

      it "returns feature reviews for itself and it's descendants" do
        expect(feature_review_repository).to receive(:feature_reviews_for)
          .with(
            versions: [sha_for_E, sha_for_F, sha_for_C],
            at: query_time,
          )
          .and_return([feature_review_for_C, feature_review_for_E, feature_review_for_F])

        expect(query.feature_reviews.map(&:url_with_query_time)).to match_array(%w(
          base_url_for_C?apps%5Bapp1%5D=C&time=2014-08-10+14%3A40%3A48+UTC&uat_url=uat.com%2FC
          base_url_for_E?apps%5Bapp1%5D=E&time=2014-08-10+14%3A40%3A48+UTC&uat_url=uat.com%2FE
          base_url_for_F?apps%5Bapp1%5D=F&time=2014-08-10+14%3A40%3A48+UTC&uat_url=uat.com%2FF
        ))
      end
    end

    describe 'the returned feature reviews' do
      let(:release) { instance_double(Release, version: sha_for_C) }

      it 'returns feature reviews that respond to :approved?' do
        allow(feature_review_repository).to receive(:feature_reviews_for)
          .and_return([feature_review_for_C, feature_review_for_E, feature_review_for_F])

        expect(query.feature_reviews.all? {|fr|
          fr.respond_to?(:approved?)
        }).to be true
      end
    end
  end

  private

  def version_for(pretend_version)
    test_git_repo.commit_for_pretend_version(pretend_version)
  end
end
