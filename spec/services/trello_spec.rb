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
  let(:service) { described_class.new('verification', {}) }
  let(:client) { double 'Trello::Client' }

  before do 
    Trello::Client.stub(:new).with(developer_public_key: 'trello_key', member_token: 'trello_token').and_return client
    client.stub(:find).with(:boards, 'aWXeu09f').and_return board
  end

  it 'has title' do
    expect(described_class.title).to eq 'Trello'
  end

  describe '.pages' do
    describe 'first' do
      subject { described_class.pages[0] }

      specify { expect(subject[:title]).to eq 'Board' }
      specify { expect(subject[:attrs]).to eq [:board, :list] }
    end

    describe 'second' do
      subject { described_class.pages[1] }

      specify { expect(subject[:title]).to eq 'Credentials' }
      specify { expect(subject[:attrs]).to eq [:key, :token] }
    end
  end

  describe '#receive_verification' do
    subject(:receive_verification) { service.receive_verification(config, nil) }

    before do
      client.should_receive(:find).with(:boards, 'aWXeu09f') do
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
        expect(receive_verification.first).to be_true
      end
    end

    context 'failure' do
      context 'board not found' do
        let(:find_result) { :board_not_found }

        it 'sets success flag to false' do
          expect(receive_verification.first).to be_false
        end

        it 'sets failure message' do
          expect(receive_verification.last).to include "not found"
        end
      end

      context 'list not found' do
        let(:lists) { [] }
        let(:find_result) { :board_with_list }

        it 'sets success flag to false' do
          expect(receive_verification.first).to be_false
        end

        it 'sets failure message' do
          expect(receive_verification.last).to include "Unable to find list"
        end
      end

      context 'invalid key' do
        let(:find_result) { :invalid_key }

        it 'sets success flag to false' do
          expect(receive_verification.first).to be_false
        end

        it 'sets failure message' do
          expect(receive_verification.last).to include "trello_key is invalid"
        end
      end

      context 'invalid token' do
        let(:find_result) { :invalid_token }

        it 'sets success flag to false' do
          expect(receive_verification.first).to be_false
        end

        it 'sets failure message' do
          expect(receive_verification.last).to include "trello_token is invalid"
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

    subject { service.receive_issue_impact_change(config, crashlytics_issue) }

    context 'success' do
      let(:card) { double 'Trello::Card', id: 'card123' }

      before { client.should_receive(:create).with(:card, card_params).and_return card }

      it 'returns a hash containing created card id' do
        expect(subject).to eq({ trello_card_id: 'card123' })
      end
    end

    context 'failure' do
      before { client.should_receive(:create).with(:card, card_params).and_raise Trello::Error }

      it 'raises an error' do
        expect { subject }.to raise_error Trello::Error
      end
    end
  end
end
