require 'spec_helper'

describe Service::OpsGenie, :type => :service do

  before do
    @logger = double('fake-logger', :log => nil)
    @config = { :api_key => 'OpsGenie API key' }
    @service = Service::OpsGenie.new(@config, lambda { |message| @logger.log(message) })
  end

  it 'has a title' do
    expect(Service::OpsGenie.title).to eq('OpsGenie')
  end

  describe 'schema and display configuration' do
    subject { Service::OpsGenie }

    it { is_expected.to include_password_field :api_key }
  end

  describe 'receive_verification' do

    it 'should succeed upon successful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.post('/') { [200, {}, ''] }
        end
      end

      allow(@service).to receive(:http_post)
        .with('https://api.opsgenie.com/v1/json/crashlytics')
        .and_return(test.post('/'))

      @service.receive_verification
      expect(@logger).to have_received(:log).with('verification successful')
    end

    it 'fails upon unsuccessful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.post('/') { [500, {}, ''] }
        end
      end

      allow(@service).to receive(:http_post)
        .with('https://api.opsgenie.com/v1/json/crashlytics')
        .and_return(test.post('/'))

      expect {
        @service.receive_verification
      }.to raise_error(Service::DisplayableError, "Couldn't verify OpsGenie settings; please check your API key.")
    end
  end

  describe 'receive_issue_impact_change' do
    it 'succeeds upon successful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.post('/v1/json/crashlytics') { [200, {}, "{}"] }
        end
      end

      allow(@service).to receive(:http_post)
        .with('https://api.opsgenie.com/v1/json/crashlytics')
        .and_return(test.post('/v1/json/crashlytics'))

      @service.receive_issue_impact_change(@config)
      expect(@logger).to have_received(:log).with('issue_impact_change successful')
    end

    it 'fails upon unsuccessful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.post('/v1/json/crashlytics') { [500, {}, "title not given"] }
        end
      end

      allow(@service).to receive(:http_post)
        .with('https://api.opsgenie.com/v1/json/crashlytics')
        .and_return(test.post('/v1/json/crashlytics'))

      expect {
        @service.receive_issue_impact_change(@config)
      }.to raise_error(Service::DisplayableError, 'OpsGenie issue creation failed - HTTP status code: 500')
    end
  end
end
