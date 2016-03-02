require 'spec_helper'

describe Service::ChatWork, :type => :service do
  let(:config) do
    {
      :api_token => 'TOooooooooooooooooooooooooooOKEN',
      :room => 'ROOM_ID'
    }
  end
  let(:logger) { double('fake-logger', :log => nil) }
  let(:service) { Service::ChatWork.new(config, lambda { |message| logger.log(message) }) }

  it 'has a title' do
    expect(Service::ChatWork.title).to eq('ChatWork')
  end

  describe 'schema and display configuration' do
    subject { Service::ChatWork }

    it { is_expected.to include_password_field :api_token }
    it { is_expected.to include_string_field :room }
  end

  describe :receive_verification do
    it 'should succeed upon successful api response' do
      expect(service).to receive(:verification_message)
      expect(service).to receive(:send_message)
      service.receive_verification
      expect(logger).to have_received(:log).with('verification successful')
    end

    it 'should fail upon unsuccessful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.post("v1/rooms/#{config[:room]}/messages") { [500, {}, ''] }
        end
      end

      expect(service).to receive(:http_post)
        .with("https://api.chatwork.com/v1/rooms/#{config[:room]}/messages")
        .and_return(test.post("v1/rooms/#{config[:room]}/messages"))

      expect(service).to receive(:verification_message)

      expect {
        service.receive_verification
      }.to raise_error(Service::DisplayableError, 'Could not send a message to room - HTTP status code: 500')
    end
  end

  describe :receive_issue_impact_change do
    let(:payload) do
      {
        :title => 'issue title',
        :method => 'method name',
        :impact_level => 1,
        :impacted_devices_count => 1,
        :crashes_count => 1,
        :app => {
          :name => 'app name',
          :bundle_identifier => 'foo.bar.baz',
          :platform => 'ios'
        },
        :url => "http://foo.com/bar"
      }
    end

    it 'should succeed upon successful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          response = '{"message_id":12345}'
          stub.post("v1/rooms/#{config[:room]}/messages") { [201, {}, response] }
        end
      end

      expect(service).to receive(:http_post)
        .with("https://api.chatwork.com/v1/rooms/#{config[:room]}/messages")
        .and_return(test.post("v1/rooms/#{config[:room]}/messages"))

      service.receive_issue_impact_change(payload)
      expect(logger).to have_received(:log).with('issue_impact_change successful')
    end

    it 'should fail upon unsuccessful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.post("v1/rooms/#{config[:room]}/messages") { [500, {}, ''] }
        end
      end

      expect(service).to receive(:http_post)
        .with("https://api.chatwork.com/v1/rooms/#{config[:room]}/messages")
        .and_return(test.post("v1/rooms/#{config[:room]}/messages"))

      expect {
        service.receive_issue_impact_change(payload)
      }.to raise_error(Service::DisplayableError, 'Could not send a message to room - HTTP status code: 500')
    end
  end
end
