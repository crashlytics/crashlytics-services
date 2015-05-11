require 'spec_helper'

describe Service::OpsGenie do
  it 'has a title' do
    Service::OpsGenie.title.should == 'OpsGenie'
  end

  describe 'receive_verification' do
    before do
      @config = { :api_key => 'OpsGenie API key' }
      @service = Service::OpsGenie.new('verification', {})
      @payload = 'does not matter'
    end

    it 'responds to receive_verification' do
      @service.respond_to?(:receive_verification)
    end

    it 'should succeed upon successful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.post('/') { [200, {}, ''] }
        end
      end

      @service.should_receive(:http_post)
        .with('https://api.opsgenie.com/v1/json/crashlytics')
        .and_return(test.post('/'))

      resp = @service.receive_verification(@config, @payload)
      resp.should == [true,  'Successfully verified OpsGenie settings']
    end

    it 'fails upon unsuccessful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.post('/') { [500, {}, ''] }
        end
      end

      @service.should_receive(:http_post)
        .with('https://api.opsgenie.com/v1/json/crashlytics')
        .and_return(test.post('/'))

      resp = @service.receive_verification(@config, @payload)
      resp.should == [false, "Couldn't verify OpsGenie settings; please check your API key."]
    end
  end

  describe 'receive_issue_impact_change' do
    before do
      @config = {}
      @service = Service::OpsGenie.new('issue_impact_change', {})
      @payload = 'does not matter'
    end

    it 'responds to receive_issue_impact_change' do
      @service.respond_to?(:receive_issue_impact_change)
    end

    it 'succeeds upon successful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.post('/v1/json/crashlytics') { [200, {}, "{}"] }
        end
      end

      @service.should_receive(:http_post)
        .with('https://api.opsgenie.com/v1/json/crashlytics')
        .and_return(test.post('/v1/json/crashlytics'))

      resp = @service.receive_issue_impact_change(@config, @payload)
      resp.should == :no_resource
    end

    it 'fails upon unsuccessful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.post('/v1/json/crashlytics') { [500, {}, "title not given"] }
        end
      end

      @service.should_receive(:http_post)
        .with('https://api.opsgenie.com/v1/json/crashlytics')
        .and_return(test.post('/v1/json/crashlytics'))

      expect { @service.receive_issue_impact_change(@config, @payload) }.to raise_error 'OpsGenie issue creation failed: 500 - title not given'
    end
  end
end
