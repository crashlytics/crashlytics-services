require 'spec_helper'
require 'ostruct'

describe Service::Hall, :type => :service do

  before do
    @config = { :group_token => 'sometoken' }
    @logger = double('fake-logger', :log => nil)
    @payload = {}
    @success = OpenStruct.new(:status => 200)
    @failure = OpenStruct.new(:status => 404, :body => "fakebody")
    @service = Service::Hall.new(@config, lambda { |message| @logger.log(message) })
  end

  it 'has a title' do
    expect(Service::Hall.title).to eq('Hall')
  end

  describe 'schema and display configuration' do
    subject { Service::Hall }

    it { is_expected.to include_string_field :group_token }
  end

  describe 'receive_verification' do
    it 'should succeed upon successful api response' do
      allow(@service).to receive(:verify_hall_service).with(@config) {@success}
      @service.receive_verification
      expect(@logger).to have_received(:log).with('verification successful')
    end

    it 'should fail upon unsuccessful api response' do
      allow(@service).to receive(:verify_hall_service).with(@config) {@failure}
      expect {
        @service.receive_verification
      }.to raise_error(Service::DisplayableError, 'Oops! Please check your Group API Token.')
    end
  end

  describe 'receive_issue_impact_change' do
    it 'should succeed upon successful api response' do
      allow(@service).to receive(:send_hall_message).with(@config, @payload) {@success}
      @service.receive_issue_impact_change(@payload)
      expect(@logger).to have_received(:log).with('issue_impact_change successful')
    end

    it 'should fail upon unsuccessful api response' do
      allow(@service).to receive(:send_hall_message).with(@config, @payload) {@failure}
      expect {
        @service.receive_issue_impact_change(@payload)
      }.to raise_error(Service::DisplayableError, /Failed to send Hall message - HTTP status code: 404/)
    end
  end
end
