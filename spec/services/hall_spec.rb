require 'spec_helper'
require 'ostruct'

describe Service::Hall do

  before do 
    @config = { :group_token => 'sometoken' }
    @payload = {}
    @success = OpenStruct.new(:status => 200)
    @failure = OpenStruct.new(:status => 404, :body => "fakebody")
  end


  it 'should have a title' do
    Service::Hall.title.should == 'Hall'
  end

  describe 'receive_verification' do
    before do
      @service = Service::Hall.new('verification', {})
    end

    it 'should respond' do
      @service.respond_to?(:receive_verification)
    end

    it 'should succeed upon successful api response' do
      @service.stub(:verify_hall_service).with(@config) {@success}
      resp = @service.receive_verification(@config, @payload)
      resp[0].should be_true
    end

    it 'should fail upon unsuccessful api response' do
      @service.stub(:verify_hall_service).with(@config) {@failure}
      resp = @service.receive_verification(@config, @payload)
      resp[0].should be_false
    end
  end

  describe 'receive_issue_impact_change' do
    before do
      @service = Service::Hall.new('issue_impact_change', {})
    end

    it 'should respond to receive_issue_impact_change' do
      @service.respond_to?(:receive_issue_impact_change)
    end

    it 'should succeed upon successful api response' do
      @service.stub(:send_hall_message).with(@config, @payload) {@success}
      resp = @service.receive_issue_impact_change(@config, @payload)
      resp.should be_true
    end

    it 'should fail upon unsuccessful api response' do
      @service.stub(:send_hall_message).with(@config, @payload) {@failure}
      lambda { 
        @service.receive_issue_impact_change(@config, @payload) 
      }.should raise_error(/Failed to send Hall message. HTTP status code: 404, body: fakebody/)
    end
  end
end
