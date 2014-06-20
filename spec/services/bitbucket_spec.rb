require 'spec_helper'

describe Service::Bitbucket do

  before do
    @config = { :username => 'user_name', :repo => 'project_name' }
  end

  it 'should have a title' do
    Service::Bitbucket.title.should == 'Bitbucket'
  end

  describe 'receive_verification' do
    before do
      @service = Service::Bitbucket.new('verification', {})
      @payload = {}
    end

    it 'should respond' do
      @service.respond_to?(:receive_verification)
    end

    it 'should succeed upon successful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.get('api/1.0/repositories/user_name/project_name/issues') { [200, {}, ''] }
        end
      end

      @service.should_receive(:http_get)
        .with('https://bitbucket.org/api/1.0/repositories/user_name/project_name/issues')
        .and_return(test.get('/api/1.0/repositories/user_name/project_name/issues'))

      resp = @service.receive_verification(@config, @payload)
      resp.should == [true, 'Successfully verified Bitbucket settings']
    end

    it 'should fail upon unsuccessful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.get('/api/1.0/repositories/user_name/project_name/issues') { [500, {}, ''] }
        end
      end

      @service.should_receive(:http_get)
        .with('https://bitbucket.org/api/1.0/repositories/user_name/project_name/issues')
        .and_return(test.get('/api/1.0/repositories/user_name/project_name/issues'))

      resp = @service.receive_verification(@config, @payload)
      resp.should == [false, 'Oops! Please check your settings again.']
    end
  end

  describe 'receive_issue_impact_change' do
    before do
      @service = Service::Bitbucket.new('issue_impact_change', {})
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
          stub.post('/api/1.0/repositories/user_name/project_name/issues') { [200, {}, "{\"local_id\":12345}"] }
        end
      end

      @service.should_receive(:http_post)
        .with('https://bitbucket.org/api/1.0/repositories/user_name/project_name/issues')
        .and_return(test.post('/api/1.0/repositories/user_name/project_name/issues'))

      resp = @service.receive_issue_impact_change(@config, @payload)
      resp.should == { :bitbucket_issue_id => 12345 }
    end

    it 'should fail upon unsuccessful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.post('/api/1.0/repositories/user_name/project_name/issues') { [500, {}, "fakebody"] }
        end
      end

      @service.should_receive(:http_post)
        .with('https://bitbucket.org/api/1.0/repositories/user_name/project_name/issues')
        .and_return(test.post('/api/1.0/repositories/user_name/project_name/issues'))

      lambda { 
        @service.receive_issue_impact_change(@config, @payload) 
      }.should raise_error(/Bitbucket issue creation failed: 500, body: fakebody/)
    end
  end
end
