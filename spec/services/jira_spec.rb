require 'spec_helper'

describe Service::Jira do
  it 'should have a title' do
    Service::Jira.title.should == 'Jira 5'
  end

  it 'should have a logo' do
    Service::Jira.logo.should == 'v1/settings/app_settings/jira.png'
  end

  describe 'receive_verification' do
    before do
      @config = { :project_url => 'https://domain.atlassian.net/browse/project_key' }
      @service = Service::Jira.new('verification', {})
      @payload = {}
    end

    it 'should respond' do
      @service.respond_to?(:receive_verification)
    end

    it 'should succeed upon successful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.get('/rest/api/2/project/project_key') { [200, {}, ''] }
        end
      end

      @service.should_receive(:http_get)
        .with('https://domain.atlassian.net/rest/api/2/project/project_key')
        .and_return(test.get('/rest/api/2/project/project_key'))

      resp = @service.receive_verification(@config, @payload)
      resp.should == [true, 'Successfully verified Jira settings']
    end

    it 'should fail upon unsuccessful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.get('/rest/api/2/project/project_key') { [500, {}, ''] }
        end
      end

      @service.should_receive(:http_get)
        .with('https://domain.atlassian.net/rest/api/2/project/project_key')
        .and_return(test.get('/rest/api/2/project/project_key'))

      resp = @service.receive_verification(@config, @payload)
      resp.should == [false, 'Oops! Please check your settings again.']
    end
  end

  describe 'receive_issue_impact_change' do
    before do
      @config = { :project_url => 'https://domain.atlassian.net/browse/project_key' }
      @service = Service::Jira.new('issue_impact_change', {})
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

    it 'should respond to receive_issue_impact_change' do
      @service.respond_to?(:receive_issue_impact_change)
    end

    it 'should succeed upon successful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.post('/rest/api/2/project/project_key') { [201, {}, "{\"id\":\"foo\"}"] }
          stub.get('/rest/api/2/project/project_key') { [200, {}, "{\"id\":12345}"] }
        end
      end

      @service.should_receive(:http_get)
        .with('https://domain.atlassian.net/rest/api/2/project/project_key')
        .and_return(test.get('/rest/api/2/project/project_key'))

      @service.should_receive(:http_post)
        .with('https://domain.atlassian.net/rest/api/2/issue')
        .and_return(test.post('/rest/api/2/project/project_key'))

      resp = @service.receive_issue_impact_change(@config, @payload)
      resp.should == { :jira_story_id => 'foo' }
    end

    it 'should fail upon unsuccessful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.post('/rest/api/2/project/project_key') { [500, {}, "{\"id\":\"foo\"}"] }
          stub.get('/rest/api/2/project/project_key') { [200, {}, "{\"id\":12345}"] }
        end
      end

      @service.should_receive(:http_get)
        .with('https://domain.atlassian.net/rest/api/2/project/project_key')
        .and_return(test.get('/rest/api/2/project/project_key'))

      @service.should_receive(:http_post)
        .with('https://domain.atlassian.net/rest/api/2/issue')
        .and_return(test.post('/rest/api/2/project/project_key'))

      lambda { @service.receive_issue_impact_change(@config, @payload) }.should raise_error
    end
  end
end
