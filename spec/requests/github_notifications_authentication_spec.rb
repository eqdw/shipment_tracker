require 'rails_helper'

RSpec.describe 'Authentication for GitHub Notifications' do
  describe 'authentication with a cookie' do
    before do
      login_with_omniauth(email: 'alice@fundingcircle.com')
    end

    it 'is not forbidden' do
      post '/github_notifications'

      expect(response).to_not be_forbidden
    end
  end

  describe 'authentication with a token in the path' do
    context 'when the token is valid' do
      let(:token) { 'abc123' }

      before do
        allow(Token).to receive(:valid?).and_return(false)
        allow(Token).to receive(:valid?).with('github_notifications', token).and_return(true)
      end

      it 'is not forbidden' do
        post "/github_notifications?token=#{token}"

        expect(response).to_not be_forbidden
      end

      it 'does not create an authorised session' do
        post "/github_notifications?token=#{token}"
        post '/github_notifications'

        expect(response).to be_forbidden
      end
    end

    context 'with an invalid token' do
      it 'is forbidden' do
        post '/github_notifications?token=asdfasdf'

        expect(response).to be_forbidden
      end
    end
  end

  describe 'authentication with no token or cookie' do
    it 'is forbidden' do
      post '/github_notifications'

      expect(response).to be_forbidden
    end
  end
end
