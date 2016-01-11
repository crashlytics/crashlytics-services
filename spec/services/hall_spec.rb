require 'spec_helper'
require 'ostruct'

describe Service::Hall do

  before do
    @config = { :group_token => 'sometoken' }
    @payload = {}
    @success = OpenStruct.new(:status => 200)
    @failure = OpenStruct.new(:status => 404, :body => "fakebody")
  end

  it 'has a title' do
    expect(Service::Hall.title).to eq('Hall')
  end

  describe 'schema and display configuration' do
    subject { Service::Hall }

    it { is_expected.to include_string_field :group_token }

    it { is_expected.to include_page 'Group API Token', [:group_token] }
  end

  describe 'receive_verification' do
    before do
      @service = Service::Hall.new('verification', {})
    end

    it 'should succeed upon successful api response' do
      allow(@service).to receive(:verify_hall_service).with(@config) {@success}
      resp = @service.receive_verification(@config, @payload)
      expect(resp[0]).to be true
    end

    it 'should fail upon unsuccessful api response' do
      allow(@service).to receive(:verify_hall_service).with(@config) {@failure}
      resp = @service.receive_verification(@config, @payload)
      expect(resp[0]).to be false
    end
  end

  describe 'receive_issue_impact_change' do
    before do
      @service = Service::Hall.new('issue_impact_change', {})
    end

    it 'should succeed upon successful api response' do
      allow(@service).to receive(:send_hall_message).with(@config, @payload) {@success}
      resp = @service.receive_issue_impact_change(@config, @payload)
      expect(resp).to eq(:no_resource)
    end

    it 'should fail upon unsuccessful api response' do
      allow(@service).to receive(:send_hall_message).with(@config, @payload) {@failure}
      expect {
        @service.receive_issue_impact_change(@config, @payload)
      }.to raise_error(/Failed to send Hall message - HTTP status code: 404, body: fakebody/)
    end
  end
end
