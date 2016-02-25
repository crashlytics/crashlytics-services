require 'spec_helper'

describe Service::Trello do
  let(:config) do
    { key:   'trello_key',
      token: 'trello_token',
      board: 'aWXeu09f',
      list:  'Crashes'
    }
  end
  let(:board) { double('Trello::Board', lists: lists) }
  let(:list) { double('Trello::List', id: 'abc123', name: 'Crashes') }
  let(:lists) { [list] }
  let(:logger) { double('fake-logger', :log => nil) }
  let(:service) { described_class.new(config, lambda { |message| logger.log(message) }) }
  let(:client) { double 'Trello::Client' }

  before do
    allow(Trello::Client).to receive(:new).with(:developer_public_key => 'trello_key', :member_token => 'trello_token').and_return client
    allow(client).to receive(:find).with(:boards, 'aWXeu09f').and_return board
  end

  it 'has a title' do
    expect(described_class.title).to eq('Trello')
  end

  describe 'schema and display configuration' do
    subject { Service::Trello }

    it { is_expected.to include_string_field :board }
    it { is_expected.to include_string_field :list }
    it { is_expected.to include_string_field :key }
    it { is_expected.to include_string_field :token }
  end

  describe '#receive_verification' do
    before do
      expect(client).to receive(:find).with(:boards, 'aWXeu09f') do
        case find_result
        when :board_with_list
          board
        when :board_not_found
          raise Trello::Error, 'invalid id'
        when :invalid_key
          raise Trello::Error, 'invalid key'
        when :invalid_token
          raise Trello::Error, 'invalid token'
        end
      end
    end

    context 'success' do
      let(:find_result) { :board_with_list }

      it 'sets success flag to true' do
        service.receive_verification
        expect(logger).to have_received(:log).with('verification successful')
      end
    end

    context 'failure' do
      context 'board not found' do
        let(:find_result) { :board_not_found }

        it 'displays an error' do
          expect {
            service.receive_verification
          }.to raise_error(Service::DisplayableError, 'Board aWXeu09f was not found')
        end
      end

      context 'list not found' do
        let(:lists) { [] }
        let(:find_result) { :board_with_list }

        it 'displays an error' do
          expect {
            service.receive_verification
          }.to raise_error(Service::DisplayableError, 'Unable to find list Crashes in board aWXeu09f')
        end

      end

      context 'invalid key' do
        let(:find_result) { :invalid_key }

        it 'displays an error' do
          expect {
            service.receive_verification
          }.to raise_error(Service::DisplayableError, 'Key trello_key is invalid')
        end
      end

      context 'invalid token' do
        let(:find_result) { :invalid_token }

        it 'displays an error' do
          expect {
            service.receive_verification
          }.to raise_error(Service::DisplayableError, 'Token trello_token is invalid')
        end
      end
    end
  end

  describe '#receive_issue_impact_change' do
    let(:crashlytics_issue) do
      { url: 'http://crashlytics.com/issue-url',
        app: { name: 'my app' },
        title: 'Fatal Error',
        method: 'my#method',
        crashes_count: '120',
        impacted_devices_count: '25'
      }
    end
    let(:expected_card_description) do
      <<-EOT
#### in my#method

* Number of crashes: 120
* Impacted devices: 25

There's a lot more information about this crash on crashlytics.com:
http://crashlytics.com/issue-url
EOT
    end

    let(:card_params) do
      { 'name'   => 'Fatal Error', 
        'idList' => 'abc123', 
        'desc'   => expected_card_description }
    end

    context 'success' do
      let(:card) { double 'Trello::Card', id: 'card123' }

      before { expect(client).to receive(:create).with(:card, card_params).and_return card }

      it 'returns a hash containing created card id' do
        service.receive_issue_impact_change(crashlytics_issue)
        expect(logger).to have_received(:log).with('issue_impact_change successful')
      end
    end

    context 'failure' do
      before { expect(client).to receive(:create).with(:card, card_params).and_raise Trello::Error }

      it 'raises an error' do
        expect {
          service.receive_issue_impact_change(crashlytics_issue)
        }.to raise_error Trello::Error
      end
    end
  end
end
