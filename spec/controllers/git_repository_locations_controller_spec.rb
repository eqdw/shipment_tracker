require 'rails_helper'

RSpec.describe GitRepositoryLocationsController do
  context 'when logged out' do
    let(:git_repository_location) {
      {
        'name' => 'shipment_tracker',
        'uri' => 'https://github.com/FundingCircle/shipment_tracker.git',
      }
    }

    it { is_expected.to require_authentication_on(:get, :index) }
    it {
      is_expected.to require_authentication_on(
        :post,
        :create,
        git_repository_location: git_repository_location)
    }
  end

  context 'when logged in', :logged_in do
    before do
      session[:current_user] = User.new
    end

    describe 'GET index' do
      it 'returns http success' do
        get :index
        expect(response).to have_http_status(:success)
      end
    end

    describe 'POST create' do
      subject { post :create, params }

      context 'when the GitRepositoryLocation is invalid' do
        let(:params) {
          { git_repository_location: { name: 'test', uri: 'github.com:invalid\uri' } }
        }

        it { is_expected.to render_template(:index) }

        it 'shows an error message' do
          post :create, params
          expect(flash[:error]).to be_present
        end
      end

      context 'when the GitRepositoryLocation is valid' do
        let(:params) {
          { git_repository_location: { name: 'test', uri: 'ssh://git@github.com/some/repo.git' } }
        }

        it { is_expected.to redirect_to(git_repository_locations_path) }
      end
    end
  end
end
