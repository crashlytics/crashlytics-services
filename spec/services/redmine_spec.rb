require 'spec_helper'

describe Service::Redmine do
  describe 'receive_verification' do
    before do
      @config = { :project_url => 'http://redmine.acme.com/projects/foo_project' }
      @service = Service::Redmine.new('verification', {})
      @payload = {}
    end

    it 'should succeed upon successful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.get('/issues.json') { [200, {}, ''] }
        end
      end

      @service.should_receive(:http_get)
        .with('http://redmine.acme.com/issues.json', { :key => nil, :project_id => "foo_project", :limit => 1 })
        .and_return(test.get('/issues.json'))

      resp = @service.receive_verification(@config, @payload)
      resp.should == [true,  "Successfully verified Redmine settings"]
    end

    it 'should fail upon unsuccessful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.get('/issues.json') { [500, {}, ''] }
        end
      end

      @service.should_receive(:http_get)
        .with('http://redmine.acme.com/issues.json', { :key => nil, :project_id => "foo_project", :limit => 1 })
        .and_return(test.get('/issues.json'))

      resp = @service.receive_verification(@config, @payload)
      resp.should == [false, "Oops! Please check your settings again."]
    end
  end

  describe 'receive_issue_impact_change' do
    before do
      @config = { :project_url => 'http://redmine.acme.com/projects/foo_project' }
      @service = Service::Redmine.new('issue_impact_change', {})
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
          stub.post('/issues.json') { [201, {}, "{\"issue\":{\"id\":\"foo_id\"}}"] }
        end
      end

      @service.should_receive(:http_post)
        .with('http://redmine.acme.com/issues.json')
        .and_return(test.post('/issues.json'))

      resp = @service.receive_issue_impact_change(@config, @payload)
      resp.should == { :redmine_issue_id => 'foo_id' }
    end

    it 'should fail upon unsuccessful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.post('/issues.json') { [500, {}, "{\"issue\":{\"id\":\"foo_id\"}}"] }
        end
      end

      @service.should_receive(:http_post)
        .with('http://redmine.acme.com/issues.json')
        .and_return(test.post('/issues.json'))

      lambda { @service.receive_issue_impact_change(@config, @payload) }.should raise_error
    end
  end
end
