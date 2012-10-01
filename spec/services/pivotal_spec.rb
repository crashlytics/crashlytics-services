require 'spec_helper'

describe Service::Pivotal do
  it 'should have a logo' do
    Service::Pivotal.logo.should == 'v1/settings/app_settings/pivotal.png'
  end

  describe 'receive_verification' do
    before do
      @config = { :project_url => 'https://www.pivotaltracker.com/projects/foo_project' }
      @service = Service::Pivotal.new('verification', {})
      @payload = {}
    end

    it 'should respond' do
      @service.respond_to?(:receive_verification)
    end

    it 'should succeed upon successful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.get('/services/v3/projects/foo_project') { [200, {}, ''] }
        end
      end

      @service.should_receive(:http_get)
        .with('https://www.pivotaltracker.com/services/v3/projects/foo_project')
        .and_return(test.get('/services/v3/projects/foo_project'))

      resp = @service.receive_verification(@config, @payload)
      resp.should == [true,  "Successfully verified Pivotal settings"]
    end

    it 'should fail upon unsuccessful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.get('/services/v3/projects/foo_project') { [500, {}, ''] }
        end
      end

      @service.should_receive(:http_get)
        .with('https://www.pivotaltracker.com/services/v3/projects/foo_project')
        .and_return(test.get('/services/v3/projects/foo_project'))

      resp = @service.receive_verification(@config, @payload)
      resp.should == [false, "Oops! Please check your settings again."]
    end
  end

  describe 'receive_issue_impact_change' do
    before do
      @config = { :project_url => 'https://www.pivotaltracker.com/projects/foo_project' }
      @service = Service::Pivotal.new('issue_impact_change', {})
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
          response = '<?xml version="1.0" encoding="UTF-8"?><story><id type="integer">foo_id</id></story>'
          stub.post('/services/v3/projects/foo_project/stories') { [201, {}, response] }
        end
      end

      @service.should_receive(:http_post)
        .with('https://www.pivotaltracker.com/services/v3/projects/foo_project/stories')
        .and_return(test.post('/services/v3/projects/foo_project/stories'))

      resp = @service.receive_issue_impact_change(@config, @payload)
      resp.should == { :pivotal_story_id => 'foo_id' }
    end

    it 'should fail upon unsuccessful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.post('/services/v3/projects/foo_project/stories') { [500, {}, ''] }
        end
      end

      @service.should_receive(:http_post)
        .with('https://www.pivotaltracker.com/services/v3/projects/foo_project/stories')
        .and_return(test.post('/services/v3/projects/foo_project/stories'))

      lambda { @service.receive_issue_impact_change(@config, @payload) }.should raise_error
    end
  end
end
