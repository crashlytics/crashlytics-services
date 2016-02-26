require 'webmock/rspec'
require 'spec_helper'

describe Service::HipChat, :type => :service do

  it 'has a title' do
    expect(Service::HipChat.title).to eq('HipChat')
  end

  describe 'schema and display configuration' do
    subject { Service::HipChat }

    it { is_expected.to include_string_field :api_token }
    it { is_expected.to include_checkbox_field :v2 }
    it { is_expected.to include_string_field :room }
    it { is_expected.to include_checkbox_field :notify }
    it { is_expected.to include_string_field :url }
  end

  let(:payload) {
    { :url => 'url', :app => { :name => 'name' }, :title => 'title', :method => 'method' }
  }

  describe :v1 do

    let(:config) do
      {
        :api_token => 'token',
        :room => 'room id',
        :notify => nil
      }
    end
    let(:logger) { double('fake-logger', :log => nil) }
    let(:service) { Service::HipChat.new(config, lambda { |message| logger.log(message) }) }
    let(:v1_verify_body) { {"color"=>"yellow", "from"=>"Crashlytics", "message"=>"verified", "message_format"=>"html", "notify"=>"0", "room_id"=>"room id"} }
    let(:v1_issue_change_body) { {"color"=>"yellow", "from"=>"Crashlytics", "message"=>"<a href=url>[name - ] Issue #: title method</a>", "message_format"=>"html", "notify"=>"0", "room_id"=>"room id"} }
    let(:v1_headers) { {'Accept'=>'application/json', 'Content-Type'=>'application/x-www-form-urlencoded'} }
    let(:v1_api_url) { "https://api.hipchat.com/v1/rooms/message?auth_token=token" }

    describe :receive_verification do
      it :success do
        expect(service).to receive(:verification_message).and_return("verified")
        stub_request(:post, v1_api_url).
         with(:body => v1_verify_body, :headers => v1_headers).
         to_return(:status => 200, :body => "", :headers => {})

        service.receive_verification
        expect(logger).to have_received(:log).with('verification successful')
      end

      it :failure do
        expect(service).to receive(:verification_message).and_return("verified")
        stub_request(:post, v1_api_url).
         with(:body => v1_verify_body, :headers => v1_headers).
         to_return(:status => 501, :body => "", :headers => {})

        expect {
          service.receive_verification
        }.to raise_error(Service::DisplayableError, /Could not send a message to room room id/)
      end
    end

    describe :receive_issue_impact_change do
      it do
        stub_request(:post, v1_api_url).
         with(:body => v1_issue_change_body, :headers => v1_headers).
         to_return(:status => 200, :body => "", :headers => {})

        service.receive_issue_impact_change(payload)
        expect(logger).to have_received(:log).with('issue_impact_change successful')
      end

      it 'surfaces exceptions as runtime errors' do
        stub_request(:post, v1_api_url).
         with(:body => v1_issue_change_body, :headers => v1_headers).
         to_return(:status => 501, :body => "", :headers => {})

        expect {
          service.receive_issue_impact_change(payload)
        }.to raise_error(/Could not send a message/)
      end
    end
  end

  describe :v2 do

    let(:config) do
      {
        :api_token => 'token',
        :room => 'room id',
        :notify => nil,
        :v2 => true
      }
    end
    let(:logger) { double('fake-logger', :log => nil) }
    let(:service) { Service::HipChat.new(config, lambda { |message| logger.log(message) }) }
    let(:v2_verify_body) { "{\"room_id\":\"room id\",\"from\":\"Crashlytics\",\"message\":\"verified\",\"message_format\":\"html\",\"color\":\"yellow\",\"notify\":false}" }
    let(:v2_issue_change_body) { "{\"room_id\":\"room id\",\"from\":\"Crashlytics\",\"message\":\"<a href=url>[name - ] Issue #: title method</a>\",\"message_format\":\"html\",\"color\":\"yellow\",\"notify\":false}" }
    let(:v2_headers) { {'Accept'=>'application/json', 'Content-Type'=>'application/json'} }
    let(:v2_api_url) { "https://api.hipchat.com/v2/room/room%20id/notification?auth_token=token" }

    describe :receive_verification do
      it :success do
        expect(service).to receive(:verification_message).and_return("verified")
        stub_request(:post, v2_api_url).
         with(:body => v2_verify_body, :headers => v2_headers).
         to_return(:status => 200, :body => "", :headers => {})

        service.receive_verification
        expect(logger).to have_received(:log).with('verification successful')
      end

      it :failure do
        expect(service).to receive(:verification_message).and_return("verified")
        stub_request(:post, v2_api_url).
         with(:body => v2_verify_body, :headers => v2_headers).
         to_return(:status => 501, :body => "", :headers => {})

        expect {
          service.receive_verification
        }.to raise_error(Service::DisplayableError, /Could not send a message to room room id/)
      end
    end

    describe :receive_issue_impact_change do
      it do
        stub_request(:post, v2_api_url).
         with(:body => v2_issue_change_body, :headers => v2_headers).
         to_return(:status => 200, :body => "", :headers => {})

        service.receive_issue_impact_change(payload)
        expect(logger).to have_received(:log).with('issue_impact_change successful')
      end

      it 'surfaces exceptions as runtime errors' do
        stub_request(:post, v2_api_url).
         with(:body => v2_issue_change_body, :headers => v2_headers).
         to_return(:status => 501, :body => "", :headers => {})

        expect {
          service.receive_issue_impact_change(payload)
        }.to raise_error(/Could not send a message/)
      end
    end
  end
end
