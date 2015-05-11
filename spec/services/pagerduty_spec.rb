require 'spec_helper'

describe Service::Pagerduty do

  it 'has a title' do
    expect(Service::Pagerduty.title).to eq('Pagerduty')
  end

  describe 'schema and display configuration' do
    subject { Service::Pagerduty }

    it { is_expected.to include_string_field :api_key }
    it { is_expected.to include_page 'API Key', [:api_key] }
  end

  describe 'receive_verification' do
    before do
      @config = {}
      @service = Service::Pagerduty.new('verification', {})
      @payload = {}
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

      resp = @service.receive_verification(@config, @payload)
      expect(resp).to eq([true, 'Successfully verified Pagerduty settings'])
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

      resp = @service.receive_verification(@config, @payload)
      expect(resp).to eq([false, 'Oops! Please check your API key again.'])
    end
  end

  describe 'receive_issue_impact_change' do
    before do
      @config = {}
      @service = Service::Pagerduty.new('issue_impact_change', {})
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

      resp = @service.receive_issue_impact_change(@config, @payload)
      expect(resp).to eq(:pagerduty_incident_key => 'foo')
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

      resp = @service.receive_issue_impact_change(@config, @payload)
      expect(resp).to be_nil
    end
  end
end
