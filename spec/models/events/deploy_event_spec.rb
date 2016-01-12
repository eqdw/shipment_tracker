require 'rails_helper'

RSpec.describe Events::DeployEvent do
  subject { Events::DeployEvent.new(details: payload) }

  context 'when given a valid payload' do
    context 'when the payload comes from Heroku' do
      let(:payload) {
        {
          'app' => 'nameless-forest',
          'user' => 'user@example.com',
          'url' => 'http://nameless-forest.herokuapp.com',
          'head_long' => '123abc',
        }
      }

      it 'returns the correct values' do
        expect(subject.app_name).to eq('nameless-forest')
        expect(subject.server).to eq('http://nameless-forest.herokuapp.com')
        expect(subject.version).to eq('123abc')
        expect(subject.deployed_by).to eq('user@example.com')
      end
    end

    let(:payload) {
      {
        'app_name' => 'soMeApp',
        'servers' => ['prod1.example.com', 'prod2.example.com'],
        'version' => '123abc',
        'deployed_by' => 'bob',
      }
    }

    it 'returns the correct values' do
      expect(subject.app_name).to eq('someapp')
      expect(subject.server).to eq('prod1.example.com')
      expect(subject.version).to eq('123abc')
      expect(subject.deployed_by).to eq('bob')
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
      expect(subject.app_name).to be_nil
      expect(subject.server).to be_nil
      expect(subject.version).to be_nil
      expect(subject.deployed_by).to be_nil
    end
  end
end
