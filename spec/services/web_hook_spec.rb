require 'spec_helper'

describe Service::WebHook do
  it 'should have a title' do
    Service::WebHook.title.should == 'Web Hook'
  end

  describe 'receive_verification' do
    before do
      @config = { :url => 'https://example.org' }
      @service = Service::WebHook.new('verification', {})
      @payload = {}
    end

    it 'should succeed upon successful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.post('/') { [200, {}, ''] }
        end
      end

      @service.should_receive(:http_post)
        .with('https://example.org')
        .and_return(test.post('/'))

      resp = @service.receive_verification(@config, @payload)
      resp.should == [true,  'Successfully verified Web Hook settings']
    end

    it 'should fail upon unsuccessful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.post('/') { [500, {}, ''] }
        end
      end

      @service.should_receive(:http_post)
        .with('https://example.org')
        .and_return(test.post('/'))

      resp = @service.receive_verification(@config, @payload)
      resp.should == [false, "Oops! Please check your settings again."]
    end
  end

  describe 'receive_issue_impact_change' do
    before do
      @config = { :url => 'https://example.org' }
      @service = Service::WebHook.new('issue_impact_change', {})
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
          stub.post('/') { [201, {}, ''] }
        end
      end

      @service.should_receive(:http_post)
        .with('https://example.org')
        .and_return(test.post('/'))

      resp = @service.receive_issue_impact_change(@config, @payload)
      resp.should == :no_resource
    end

    it 'should fail with extra information upon unsuccessful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.post('/') { [500, {}, 'fake_body'] }
        end
      end

      @service.should_receive(:http_post)
        .with('https://example.org')
        .and_return(test.post('/'))

      lambda {
        @service.receive_issue_impact_change(@config, @payload)
      }.should raise_error(/WebHook issue create failed: HTTP status code: 500, body: fake_body/)
    end
  end
end
