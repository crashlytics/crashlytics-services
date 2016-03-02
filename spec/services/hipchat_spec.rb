require 'webmock/rspec'
require 'spec_helper'

describe Service::HipChat, :type => :service do

  it 'has a title' do
    expect(Service::HipChat.title).to eq('HipChat')
  end

  describe 'schema and display configuration' do
    subject { Service::HipChat }

    it { is_expected.to include_password_field :api_token }
    it { is_expected.to include_checkbox_field :v2 }
    it { is_expected.to include_string_field :room }
    it { is_expected.to include_checkbox_field :notify }
    it { is_expected.to include_string_field :url }
  end

  let(:issue_impact_change_payload) do
    {
      :url => 'url',
      :app => { :name => 'name', :bundle_identifier => 'io.fabric.test', :platform => 'android' },
      :title => 'title',
      :method => 'method',
      :impact_level => 2,
      :display_id => 4
    }
  end

  let(:issue_velocity_alert_payload) do
    {
      :url => 'url',
      :app => { :name => 'name', :bundle_identifier => 'io.fabric.test', :platform => 'android' },
      :title => 'title',
      :method => 'method',
      :impact_level => 2,
      :display_id => 4,
      :crash_percentage => 1.02,
      :version => '1.0 (1.2)'
    }
  end

  describe 'v1' do

    let(:config) do
      {
        :api_token => 'token',
        :room => 'room id',
        :notify => nil
      }
    end
    let(:logger) { double('fake-logger', :log => nil) }
    let(:service) { Service::HipChat.new(config, lambda { |message| logger.log(message) }) }
    let(:v1_headers) { {'Accept'=>'application/json', 'Content-Type'=>'application/x-www-form-urlencoded'} }
    let(:v1_api_url) { "https://api.hipchat.com/v1/rooms/message?auth_token=token" }

    describe '#receive_verification' do
      let(:fake_verification_message) { 'verified' }
      let(:v1_verify_body) do
        {
          :color => 'green',
          :from=> 'Crashlytics',
          :message => fake_verification_message,
          :message_format => 'html',
          :notify => '0',
          :room_id => 'room id'
        }
      end
      it 'logs a message on success' do
        expect(service).to receive(:verification_message).and_return(fake_verification_message)
        stub_request(:post, v1_api_url).
          with(:body => v1_verify_body, :headers => v1_headers).
          to_return(:status => 200)

        service.receive_verification
        expect(logger).to have_received(:log).with('v1 verification successful')
      end

      it 'surfaces unsuccessful attempts as displayable errors' do
        expect(service).to receive(:verification_message).and_return(fake_verification_message)
        stub_request(:post, v1_api_url).
          with(:body => v1_verify_body, :headers => v1_headers).
          to_return(:status => 501)

        expect {
          service.receive_verification
        }.to raise_error(Service::DisplayableError, 'Could not send a message to room room id - HTTP status code: 501')
      end
    end

    describe '#receive_issue_impact_change' do
      let(:v1_issue_change_body) do
        {
          :color => 'yellow',
          :from => 'Crashlytics',
          :message =>'<a href=url>[name - io.fabric.test] Issue #4: title method</a> - Just reached impact level 2',
          :message_format =>'html',
          :notify => '0',
          :room_id => 'room id'
        }
      end

      it 'logs a message on success' do
        stub_request(:post, v1_api_url).
          with(:body => v1_issue_change_body, :headers => v1_headers).
          to_return(:status => 200)

        service.receive_issue_impact_change(issue_impact_change_payload)
        expect(logger).to have_received(:log).with('v1 issue_impact_change successful')
      end

      it 'surfaces unsuccessful attempts as displayable errors' do
        stub_request(:post, v1_api_url).
          with(:body => v1_issue_change_body, :headers => v1_headers).
          to_return(:status => 501)

        expect {
          service.receive_issue_impact_change(issue_impact_change_payload)
        }.to raise_error(Service::DisplayableError, 'Could not send a message to room room id - HTTP status code: 501')
      end
    end

    describe '#receive_issue_velocity_alert' do
      let(:message_body) { 'Velocity Alert! Crashing 1.02% of all sessions in the past hour on version 1.0 (1.2)'}
      let(:v1_issue_velocity_alert_body) do
        {
          :color => 'red',
          :from => 'Crashlytics',
          :message =>"<a href=url>[name - io.fabric.test] Issue #4: title method</a> - #{message_body}",
          :message_format =>'html',
          :notify => '0',
          :room_id => 'room id'
        }
      end

      it 'logs a message on success' do
        stub_request(:post, v1_api_url).
          with(:body => v1_issue_velocity_alert_body, :headers => v1_headers).
          to_return(:status => 200)

        service.receive_issue_velocity_alert(issue_velocity_alert_payload)
        expect(logger).to have_received(:log).with('v1 issue_velocity_alert successful')
      end

      it 'surfaces unsuccessful attempts as displayable errors' do
        stub_request(:post, v1_api_url).
          with(:body => v1_issue_velocity_alert_body, :headers => v1_headers).
          to_return(:status => 501)

        expect {
          service.receive_issue_velocity_alert(issue_velocity_alert_payload)
        }.to raise_error(Service::DisplayableError, 'Could not send a message to room room id - HTTP status code: 501')
      end
    end
  end

  describe 'v2' do

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
    let(:v2_headers) { {'Accept'=>'application/json', 'Content-Type'=>'application/json'} }
    let(:v2_api_url) { "https://api.hipchat.com/v2/room/room%20id/notification?auth_token=token" }

    describe 'receive_verification' do
      let(:fake_verification_message) { 'verified' }
      let(:v2_verify_hash) do
        {
          :room_id => 'room id',
          :from => 'Crashlytics',
          :message => fake_verification_message,
          :message_format => 'html',
          :color => 'green',
          :notify => false
        }
      end
      let(:v2_verify_body) { v2_verify_hash.to_json }

      it 'logs a message on success' do
        expect(service).to receive(:verification_message).and_return(fake_verification_message)
        stub_request(:post, v2_api_url).
          with(:body => v2_verify_body, :headers => v2_headers).
          to_return(:status => 200)

        service.receive_verification
        expect(logger).to have_received(:log).with('v2 verification successful')
      end

      it 'it surfaces problems as displayable errors' do
        expect(service).to receive(:verification_message).and_return(fake_verification_message)
        stub_request(:post, v2_api_url).
          with(:body => v2_verify_body, :headers => v2_headers).
          to_return(:status => 501)

        expect {
          service.receive_verification
        }.to raise_error(Service::DisplayableError, /Could not send a message to room room id/)
      end
    end

    describe '#receive_issue_impact_change' do
      let(:v2_issue_change_hash) do
        {
          :room_id => 'room id',
          :from => 'Crashlytics',
          :message => '<a href=url>[name - io.fabric.test] Issue #4: title method</a> - Just reached impact level 2',
          :message_format => 'html',
          :color => 'yellow',
          :notify => false
        }
      end
      let(:v2_issue_change_body) { v2_issue_change_hash.to_json }

      it 'logs a message on success' do
        stub_request(:post, v2_api_url).
          with(:body => v2_issue_change_body, :headers => v2_headers).
          to_return(:status => 200)

        service.receive_issue_impact_change(issue_impact_change_payload)
        expect(logger).to have_received(:log).with('v2 issue_impact_change successful')
      end

      it 'surfaces unsuccessful attempts as displayable errors' do
        stub_request(:post, v2_api_url).
          with(:body => v2_issue_change_body, :headers => v2_headers).
          to_return(:status => 501)

        expect {
          service.receive_issue_impact_change(issue_impact_change_payload)
        }.to raise_error(Service::DisplayableError, 'Could not send a message to room room id - HTTP status code: 501')
      end
    end

    describe '#receive_issue_velocity_alert' do
      let(:message_body) { 'Velocity Alert! Crashing 1.02% of all sessions in the past hour on version 1.0 (1.2)'}
      let(:v2_issue_velocity_alert_body) do
        {
          :color => 'red',
          :from => 'Crashlytics',
          :message =>"<a href=url>[name - io.fabric.test] Issue #4: title method</a> - #{message_body}",
          :message_format =>'html',
          :notify => false,
          :room_id => 'room id'
        }
      end

      it 'logs a message on success' do
        stub_request(:post, v2_api_url).
          with(:body => v2_issue_velocity_alert_body, :headers => v2_headers).
          to_return(:status => 200)

        service.receive_issue_velocity_alert(issue_velocity_alert_payload)
        expect(logger).to have_received(:log).with('v2 issue_velocity_alert successful')
      end

      it 'surfaces unsuccessful attempts as displayable errors' do
        stub_request(:post, v2_api_url).
          with(:body => v2_issue_velocity_alert_body, :headers => v2_headers).
          to_return(:status => 501)

        expect {
          service.receive_issue_velocity_alert(issue_velocity_alert_payload)
        }.to raise_error(Service::DisplayableError, 'Could not send a message to room room id - HTTP status code: 501')
      end
    end
  end
end
