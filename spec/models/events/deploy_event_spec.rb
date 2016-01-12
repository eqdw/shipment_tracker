require 'rails_helper'

RSpec.describe Events::DeployEvent do
  subject { Events::DeployEvent.new(details: payload) }

  context 'when given a valid payload' do
    let(:payload) {
      {
        'app_name' => 'soMeApp',
        'servers' => ['prod1.example.com', 'prod2.example.com'],
        'version' => '123abc',
        'deployed_by' => 'bob',
        'environment' => 'staging',
      }
    }

    it 'returns the correct values' do
      expect(subject.app_name).to eq('someapp')
      expect(subject.server).to eq('prod1.example.com')
      expect(subject.version).to eq('123abc')
      expect(subject.deployed_by).to eq('bob')
      expect(subject.environment).to eq('staging')
    end

    context 'when the payload comes from Heroku' do
      let(:payload) {
        {
          'app' => 'nameless-forest-uat',
          'user' => 'user@example.com',
          'url' => 'http://nameless-forest-uat.herokuapp.com',
          'head_long' => '123abc',
        }
      }

      it 'returns the correct values' do
        expect(subject.app_name).to eq('nameless-forest-uat')
        expect(subject.server).to eq('http://nameless-forest-uat.herokuapp.com')
        expect(subject.version).to eq('123abc')
        expect(subject.deployed_by).to eq('user@example.com')
        expect(subject.environment).to eq('uat')
      end

      context 'when the app name does not include the environment at the end' do
        let(:payload) { { 'app' => 'nameless-forest' } }

        it 'sets the environment to nil' do
          expect(subject.environment).to be nil
        end
      end
    end

    context 'when the payload structure is deprecated' do
      let(:payload) {
        {
          'app_name' => 'soMeApp',
          'server' => 'uat.example.com',
          'version' => '123abc',
          'deployed_by' => 'bob',
        }
      }

      it 'returns the correct values' do
        expect(subject.app_name).to eq('someapp')
        expect(subject.server).to eq('uat.example.com')
        expect(subject.version).to eq('123abc')
        expect(subject.deployed_by).to eq('bob')
      end
    end
  end

  context 'when given an invalid payload' do
    let(:payload) {
      {
        'bad' => 'news',
      }
    }

    it 'returns the correct values' do
      expect(subject.app_name).to be nil
      expect(subject.server).to be nil
      expect(subject.version).to be nil
      expect(subject.deployed_by).to be nil
      expect(subject.environment).to be nil
    end
  end
end
