require 'rails_helper'

RSpec.describe ReleasesController do
  context 'when logged out' do
    it { is_expected.to require_authentication_on(:get, :index) }
    it { is_expected.to require_authentication_on(:get, :show, id: 'frontend') }
  end

  describe 'GET #index', :logged_in do
    let(:app_names) { %w(frontend backend) }

    before do
      allow(GitRepositoryLocation).to receive(:app_names).and_return(app_names)
    end

    it 'displays the list of apps' do
      get :index

      expect(response).to have_http_status(:success)
      expect(assigns(:app_names)).to eq(app_names)
    end
  end

  describe 'GET #show', :logged_in do
    let(:repository) { instance_double(GitRepository) }
    let(:repository_loader) { instance_double(GitRepositoryLoader) }
    let(:events) { double(:events) }
    let(:app_name) { 'frontend' }
    let(:pending_releases) { double(:pending_releases) }
    let(:deployed_releases) { double(:deployed_releases) }
    let(:projection) {
      instance_double(
        Projections::ReleasesProjection,
        pending_releases: pending_releases,
        deployed_releases: deployed_releases,
      )
    }

    before do
      allow(GitRepositoryLoader).to receive(:from_rails_config).and_return(repository_loader)
      allow(repository_loader).to receive(:load).with('frontend').and_return(repository)
      allow(Projections::ReleasesProjection).to receive(:new).with(
        per_page: 50,
        git_repository: repository,
        app_name: app_name,
      ).and_return(projection)
      allow(Events::BaseEvent).to receive(:in_order_of_creation).and_return(events)
    end

    it 'shows the list of commits for an app' do
      # expect(projection).to receive(:apply_all).with(events)

      get :show, id: app_name

      expect(response).to have_http_status(:success)
      expect(assigns(:app_name)).to eq(app_name)
      expect(assigns(:pending_releases)).to eq(pending_releases)
      expect(assigns(:deployed_releases)).to eq(deployed_releases)
    end

    context 'when app id does not exist' do
      before do
        allow(repository_loader).to receive(:load).and_raise(GitRepositoryLoader::NotFound)
      end

      it 'responds with a 404' do
        get :show, id: 'hokus-pokus'

        expect(response).to be_not_found
      end
    end
  end
end
