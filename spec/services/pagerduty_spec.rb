require 'spec_helper'

describe Service::Pagerduty, :type => :service do
  before do
    @logger = double('fake-logger', :log => nil)
    @config = { :api_key => 'fake-key' }
    @service = Service::Pagerduty.new(@config, lambda { |message| @logger.log(message) })
  end

  it 'has a title' do
    expect(Service::Pagerduty.title).to eq('Pagerduty')
  end

  describe 'schema and display configuration' do
    subject { Service::Pagerduty }

    it { is_expected.to include_password_field :api_key }
  end

  describe 'receive_verification' do

    it 'should succeed upon successful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.post('/generic/2010-04-15/create_event.json') { [200, {}, "{\"incident_key\":\"foo\"}"] }
        end
      end

      expect(@service).to receive(:http_post)
        .with('https://events.pagerduty.com/generic/2010-04-15/create_event.json')
        .and_return(test.post('/generic/2010-04-15/create_event.json'))

      @service.receive_verification
      expect(@logger).to have_received(:log).with('verification successful')
    end

    it 'should fail upon unsuccessful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.post('/generic/2010-04-15/create_event.json') { [500, {}, "{\"incident_key\":\"foo\"}"] }
        end
      end

      expect(@service).to receive(:http_post)
        .with('https://events.pagerduty.com/generic/2010-04-15/create_event.json')
        .and_return(test.post('/generic/2010-04-15/create_event.json'))

      expect {
        @service.receive_verification
      }.to raise_error(Service::DisplayableError, 'Pagerduty verification failed - HTTP status code: 500')
    end
  end

  describe 'receive_issue_impact_change' do
    before do
      @payload = {
        :title => 'foo title',
        :impact_level => 1,
        :impacted_devices_count => 1,
        :crashes_count => 1,
        :app => {
          :name => 'foo name',
          :bundle_identifier => 'foo.bar.baz'
        }
      }
    end

    it 'should succeed upon successful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.post('/generic/2010-04-15/create_event.json') { [200, {}, "{\"incident_key\":\"foo\"}"] }
        end
      end

      expect(@service).to receive(:http_post)
        .with('https://events.pagerduty.com/generic/2010-04-15/create_event.json')
        .and_return(test.post('/generic/2010-04-15/create_event.json'))

      @service.receive_issue_impact_change(@payload)
      expect(@logger).to have_received(:log).with('issue_impact_change successful')
    end

    it 'should fail upon unsuccessful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.post('/generic/2010-04-15/create_event.json') { [500, {}, "{\"incident_key\":\"foo\"}"] }
        end
      end

      expect(@service).to receive(:http_post)
        .with('https://events.pagerduty.com/generic/2010-04-15/create_event.json')
        .and_return(test.post('/generic/2010-04-15/create_event.json'))

      expect {
        @service.receive_issue_impact_change(@payload)
      }.to raise_error(Service::DisplayableError, 'Pagerduty issue impact change failed - HTTP status code: 500')
    end
  end
end
