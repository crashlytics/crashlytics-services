require 'spec_helper'

describe Service::Pagerduty do
  it 'should have a title' do
    Service::Pagerduty.title.should == 'Pagerduty'
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

      @service.should_receive(:http_post)
        .with('https://events.pagerduty.com/generic/2010-04-15/create_event.json')
        .and_return(test.post('/generic/2010-04-15/create_event.json'))

      resp = @service.receive_verification(@config, @payload)
      resp.should == [true, 'Successfully verified Pagerduty settings']
    end

    it 'should fail upon unsuccessful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.post('/generic/2010-04-15/create_event.json') { [500, {}, "{\"incident_key\":\"foo\"}"] }
        end
      end

      @service.should_receive(:http_post)
        .with('https://events.pagerduty.com/generic/2010-04-15/create_event.json')
        .and_return(test.post('/generic/2010-04-15/create_event.json'))

      resp = @service.receive_verification(@config, @payload)
      resp.should == [false, 'Oops! Please check your API key again.']
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

      @service.should_receive(:http_post)
        .with('https://events.pagerduty.com/generic/2010-04-15/create_event.json')
        .and_return(test.post('/generic/2010-04-15/create_event.json'))

      resp = @service.receive_issue_impact_change(@config, @payload)
      resp.should == { :pagerduty_incident_key => 'foo' }
    end

    it 'should fail upon unsuccessful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.post('/generic/2010-04-15/create_event.json') { [500, {}, "{\"incident_key\":\"foo\"}"] }
        end
      end

      @service.should_receive(:http_post)
        .with('https://events.pagerduty.com/generic/2010-04-15/create_event.json')
        .and_return(test.post('/generic/2010-04-15/create_event.json'))

      resp = @service.receive_issue_impact_change(@config, @payload)
      resp.should == nil
    end
  end
end
