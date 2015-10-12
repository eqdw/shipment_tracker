require 'rails_helper'

RSpec.describe ApplicationController, :logged_in do
  controller do
    def index
      head 200
    end
  end

  describe '#data_maintenance_warning' do
    context 'when application is in maintenance mode' do
      before do
        allow(Rails.configuration).to receive(:data_maintenance_mode).and_return(true)
      end

      context 'when the request format is html' do
        it 'shows a flash warning message' do
          get :index
          expect(flash[:warning]).to eq('The site is currently undergoing maintenance. '\
                                        'Some data may appear out-of-date. ¯\\_(ツ)_/¯')
        end
      end

      context 'when the request format is not html' do
        it 'does not show a flash warning message' do
          get :index, format: 'json'
          expect(flash[:warning]).to be nil
        end
      end
    end

    context 'when application is not in maintenance mode' do
      before do
        allow(Rails.configuration).to receive(:data_maintenance_mode).and_return(false)
      end

      it 'does not show a flash warning message' do
        get :index
        expect(flash[:warning]).to be nil
      end
    end
  end
end
