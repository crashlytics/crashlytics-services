require 'spec_helper'
require 'webmock/rspec'

describe Service::Trello, :type => :service do
  let(:config) do
    {
      :key => 'trello_key',
      :token => 'trello_token',
      :board => 'aWXeu09f',
      :list => 'Crashes'
    }
  end
  let(:board_id) { '56d06bb8505c4db753000001' }
  let(:list_id) { '56d06da3505c4db753000002'}

  let(:logger) { double('fake-logger', :log => nil) }
  let(:service) { described_class.new(config, lambda { |message| logger.log(message) }) }

  def stub_find_board
    stub_request(:get, "https://api.trello.com/1/boards/#{config[:board]}?key=#{config[:key]}&token=#{config[:token]}")
  end

  let(:board_response_body) do
    { :id => board_id }.to_json
  end

  def stub_find_lists
    stub_request(:get, "https://api.trello.com/1/boards/#{board_id}/lists?filter=open&key=#{config[:key]}&token=#{config[:token]}")
  end

  let(:list_response_body) do
    [
      {
        :id => list_id,
        :name => config[:list],
        :idBoard => board_id
      }
    ].to_json
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

  let(:expected_card_create_request_body) do
    {
      :desc => expected_card_description,
      #:due => '',
      #:idLabels => '',
      :idList => '56d06da3505c4db753000002',
      #:idMembers => '',
      :name => 'Fatal Error',
      #:pos => ''
    }
  end

  def stub_create_card
     stub_request(:post, "https://api.trello.com/1/cards?key=#{config[:key]}&token=#{config[:token]}").
       with(:body => expected_card_create_request_body)
            #:headers => {'Accept'=>'*/*; q=0.5, application/xml', 'Accept-Encoding'=>'gzip, deflate', 'Content-Length'=>'330', 'Content-Type'=>'application/x-www-form-urlencoded', 'User-Agent'=>'Ruby'})
  end

  let(:card_creation_response_body) do
    { :id => '56d08430505c4db753000003' }.to_json
  end

  it 'has a title' do
    expect(described_class.title).to eq('Trello')
  end

  describe 'schema and display configuration' do
    subject { Service::Trello }

    it { is_expected.to include_string_field :board }
    it { is_expected.to include_string_field :list }
    it { is_expected.to include_string_field :key }
    it { is_expected.to include_password_field :token }
  end

  describe '#receive_verification' do
    it 'logs a message when successful' do
      stub_find_board.and_return(:status => 200, :body => board_response_body)
      stub_find_lists.and_return(:status => 200, :body => list_response_body)
      service.receive_verification
      expect(logger).to have_received(:log).with('verification successful')
    end

    it 'displays an error when board not found' do
      stub_find_board.and_return(:status => 400, :body => 'invalid id')
      expect {
        service.receive_verification
      }.to raise_error(Service::DisplayableError, 'Board aWXeu09f was not found')
    end

    it 'displays an error when list not found' do
      stub_find_board.and_return(:status => 200, :body => board_response_body)
      stub_find_lists.and_return(:status => 200, :body => [].to_json)

      expect {
        service.receive_verification
      }.to raise_error(Service::DisplayableError, 'List Crashes not found in board aWXeu09f')
    end

    it 'displays an error when invalid key' do
      stub_find_board.and_return(:status => 401, :body => 'invalid key')
      expect {
        service.receive_verification
      }.to raise_error(Service::DisplayableError, 'Key trello_key is invalid')
    end

    it 'displays an error when invalid token' do
      stub_find_board.and_return(:status => 401, :body => 'invalid token')
      expect {
        service.receive_verification
      }.to raise_error(Service::DisplayableError, 'Token trello_token is invalid')
    end
  end

  describe '#receive_issue_impact_change' do
    let(:crashlytics_issue) do
      {
        :url => 'http://crashlytics.com/issue-url',
        :app => { name: 'my app' },
        :title => 'Fatal Error',
        :method => 'my#method',
        :crashes_count => '120',
        :impacted_devices_count => '25'
      }
    end

    let(:card_params) do
      {
        'name'   => 'Fatal Error',
        'idList' => config[:list],
        'desc'   => expected_card_description
      }
    end

    it 'logs a message on success' do
      stub_find_board.and_return(:status => 200, :body => board_response_body)
      stub_find_lists.and_return(:status => 200, :body => list_response_body)
      stub_create_card.and_return(:status => 200, :body => card_creation_response_body)

      service.receive_issue_impact_change(crashlytics_issue)
      expect(logger).to have_received(:log).with('issue_impact_change successful')
    end

    it 'raises an error on failure' do
      stub_find_board.and_return(:status => 200, :body => board_response_body)
      stub_find_lists.and_return(:status => 200, :body => list_response_body)
      stub_create_card.and_return(:status => 400, :body => 'invalid value for idList')

      expect {
        service.receive_issue_impact_change(crashlytics_issue)
      }.to raise_error(Service::DisplayableError, 'Unexpected error while creating a card - HTTP status code: 400')
    end
  end
end
