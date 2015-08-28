require 'rails_helper'

RSpec.describe FeatureReviewsController do
  context 'when logged out' do
    it { is_expected.to require_authentication_on(:get, :new) }
    it { is_expected.to require_authentication_on(:get, :show) }
    it { is_expected.to require_authentication_on(:post, :create) }
    it { is_expected.to require_authentication_on(:get, :search) }
  end

  describe 'GET #new', :logged_in do
    let(:feature_review_form) { instance_double(Forms::FeatureReviewForm) }

    before do
      allow(GitRepositoryLocation).to receive(:app_names).and_return(%w(frontend backend))
      allow(Forms::FeatureReviewForm).to receive(:new).with(
        hash_including(
          apps: nil,
          uat_url: nil,
        ),
      ).and_return(feature_review_form)
    end

    it 'renders the form' do
      get :new
      is_expected.to render_template('new')
      expect(assigns(:feature_review_form)).to eq(feature_review_form)
      expect(assigns(:app_names)).to eq(%w(frontend backend))
    end
  end

  describe 'POST #create', :logged_in do
    let(:git_repository_loader) { instance_double(GitRepositoryLoader) }
    let(:feature_review_form) { instance_double(Forms::FeatureReviewForm) }
    let(:repo) { instance_double(GitRepository) }

    before do
      allow(Forms::FeatureReviewForm).to receive(:new).with(
        apps: { frontend: 'abc' },
        uat_url: 'http://uat.example.com',
        git_repository_loader: git_repository_loader,
      ).and_return(feature_review_form)
      allow(GitRepositoryLoader).to receive(:new).and_return(git_repository_loader)
    end

    context 'when the params are invalid' do
      it 'renders the new page' do
        allow(Forms::FeatureReviewForm).to receive(:new).and_return(feature_review_form)
        allow(feature_review_form).to receive(:valid?).and_return(false)

        post :create

        is_expected.to render_template('new')
        expect(assigns(:feature_review_form)).to eql(feature_review_form)
      end
    end

    context 'when the feature review form is invalid' do
      before do
        allow(feature_review_form).to receive(:valid?).and_return(false)
        allow(GitRepositoryLocation).to receive(:app_names).and_return(%w(frontend backend))
      end

      it 'renders the new page' do
        post :create, forms_feature_review_form: {
          apps: { frontend: 'abc' }, uat_url: 'http://uat.example.com'
        }

        is_expected.to render_template('new')
        expect(assigns(:feature_review_form)).to eql(feature_review_form)
        expect(assigns(:app_names)).to eql(%w(frontend backend))
      end
    end

    context 'when the feature review form is valid' do
      before do
        allow(feature_review_form).to receive(:valid?).and_return(true)
        allow(feature_review_form).to receive(:url).and_return('/the/url')
      end

      it 'redirects to #show' do
        post :create, forms_feature_review_form: {
          apps: { frontend: 'abc' }, uat_url: 'http://uat.example.com'
        }

        is_expected.to redirect_to('/the/url')
      end
    end
  end

  describe 'GET #show', :logged_in do
    let(:events) { [Events::BaseEvent.new, Events::BaseEvent.new, Events::BaseEvent.new] }
    let(:uat_url) { 'http://uat.fundingcircle.com' }
    let(:apps_with_versions) { { 'frontend' => 'abc', 'backend' => 'def' } }

    before do
      request.host = 'www.example.com'
    end

    it 'sets up the correct query parameters' do
      get :show, apps: apps_with_versions, uat_url: uat_url

      expect(assigns(:feature_review_with_statuses).app_versions).to eq(apps_with_versions)
      expect(assigns(:feature_review_with_statuses).uat_url).to eq(uat_url)
      expect(assigns(:feature_review_with_statuses).time).to eq(nil)
    end

    context 'when time is specified' do
      it 'sets up the correct query parameters (including time)' do
        get :show, apps: apps_with_versions, uat_url: uat_url, time: '1990-12-31T23:59:59Z'

        expect(assigns(:feature_review_with_statuses).app_versions).to eq(apps_with_versions)
        expect(assigns(:feature_review_with_statuses).uat_url).to eq(uat_url)
        expect(assigns(:feature_review_with_statuses).time).to eq(Time.parse('1990-12-31T23:59:59Z'))
      end
    end
  end

  describe 'GET #search', :logged_in do
    let(:applications) { %w(frontend backend mobile) }

    let(:version_resolver) { instance_double(VersionResolver) }
    let(:repository) { instance_double(Repositories::FeatureReviewRepository) }
    let(:git_repository_loader) { instance_double(GitRepositoryLoader) }
    let(:repo) { instance_double(GitRepository) }
    let(:related_versions) { %w(abc def ghi) }
    let(:expected_links) { ['/somelink'] }
    let(:expected_feature_reviews) { [instance_double(FeatureReview, url: '/somelink')] }
    let(:version) { 'abc123' }

    before do
      allow(VersionResolver).to receive(:new).with(repo).and_return(version_resolver)
      allow(version_resolver).to receive(:related_versions).with(version).and_return(related_versions)
      allow(GitRepositoryLocation).to receive(:app_names).and_return(applications)
      allow(GitRepositoryLoader).to receive(:new).and_return(git_repository_loader)
      allow(Repositories::FeatureReviewRepository).to receive(:new).and_return(repository)
      allow(repository).to receive(:feature_reviews_for)
        .with(versions: related_versions)
        .and_return(expected_feature_reviews)

      allow(git_repository_loader).to receive(:load).with('frontend').and_return(repo)
    end

    it 'assigns links for found Feature Reviews' do
      get :search, version: version, application: 'frontend'

      expect(assigns(:links)).to eq(expected_links)
      expect(assigns(:applications)).to eq(applications)
    end
  end
end
