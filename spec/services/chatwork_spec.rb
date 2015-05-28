require 'spec_helper'

describe Service::ChatWork do
  let(:config) do
    {
      :api_token => 'TOooooooooooooooooooooooooooOKEN',
      :room => 'ROOM_ID'
    }
  end

  it 'has a title' do
    expect(Service::ChatWork.title).to eq('ChatWork')
  end

  describe 'schema and display configuration' do
    subject { Service::ChatWork }

    it { is_expected.to include_string_field :api_token }
    it { is_expected.to include_string_field :room }
    it { is_expected.to include_page 'API Token', [:api_token] }
    it { is_expected.to include_page 'Room ID', [:room] }
  end

  describe :receive_verification do
    before do
      @service = Service::ChatWork.new('verification', {})
    end

    it 'should succeed upon successful api response' do
      expect(@service).to receive(:receive_verification_message)
      expect(@service).to receive(:send_message)
      success, message = @service.receive_verification(config, nil)
      expect(success).to be true
    end

    it 'should fail upon unsuccessful api response' do
      expect(@service).to receive(:receive_verification_message)
      expect(@service).to receive(:send_message).and_raise
      success, message = @service.receive_verification(config, nil)
      expect(success).to be false
    end
  end

  describe :receive_issue_impact_change do
    before do
      @service = Service::ChatWork.new('issue_impact_change', {})
      @payload = {
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

      expect(@service).to receive(:http_post)
        .with("https://api.chatwork.com/v1/rooms/#{config[:room]}/messages")
        .and_return(test.post("v1/rooms/#{config[:room]}/messages"))

      resp = @service.receive_issue_impact_change(config, @payload)
      expect(resp).to eq('message_id' => 12345)
    end

    it 'should fail upon unsuccessful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.post("v1/rooms/#{config[:room]}/messages") { [500, {}, ''] }
        end
      end

      expect(@service).to receive(:http_post)
        .with("https://api.chatwork.com/v1/rooms/#{config[:room]}/messages")
        .and_return(test.post("v1/rooms/#{config[:room]}/messages"))

      expect { @service.receive_issue_impact_change(config, @payload) }.to raise_error
    end
  end
end
