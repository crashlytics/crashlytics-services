require 'spec_helper'
require 'webmock/rspec'

RSpec.configure do |c|
  c.filter_run_excluding :wip => true
end

describe Service::Jira do
  it 'should have a title' do
    Service::Jira.title.should == 'Jira'
  end

  describe 'receive_verification' do
    before do
      @config = { :project_url => 'https://example.com/browse/project_key' }
      @service = Service::Jira.new('verification', {})
      @payload = {}
    end

    it 'should respond' do
      expect(@service.respond_to?(:receive_verification)).to be_true
    end

    it 'should succeed upon successful api response' do
      stub_request(:get, "https://example.com/rest/api/2/project/project_key").
         with(:headers => {'Accept'=>'application/json', 'User-Agent'=>'Ruby'}).
         to_return(:status => 200, :body => "", :headers => {})

      resp = @service.receive_verification(@config, @payload)
      expect(resp).to eq([true, 'Successfully verified Jira settings'])
    end

    it 'should fail upon unsuccessful api response' do
      stub_request(:get, "https://example.com/rest/api/2/project/project_key").
         with(:headers => {'Accept'=>'application/json', 'User-Agent'=>'Ruby'}).
         to_return(:status => 500, :body => "", :headers => {})

      resp = @service.receive_verification(@config, @payload)
      expect(resp).to eq([false, 'Oops! Please check your settings again.'])
    end
  end

  describe 'jira_client' do
    it 'disables SSL checking when the project_url is http' do
      service = Service::Jira.new('verification', {})
      client = service.jira_client(:project_url => 'http://example.com/browse/project_key')
      expect(client.options[:use_ssl]).to be_false
      expect(client.options[:ssl_verify_mode]).to eq(OpenSSL::SSL::VERIFY_NONE)
    end

    it 'enables SSL checking and peer verification when the project_url is https' do
      service = Service::Jira.new('verification', {})
      client = service.jira_client(:project_url => 'https://example.com/browse/project_key')
      expect(client.options[:use_ssl]).to be_true
      expect(client.options[:ssl_verify_mode]).to eq(OpenSSL::SSL::VERIFY_PEER)
    end
  end

  describe 'receive_issue_impact_change' do
    before do
      @config = { :project_url => 'https://example.com/browse/project_key' }
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
      expect(@service.respond_to?(:receive_issue_impact_change)).to be_true
    end

    it 'should succeed upon successful api response' do
      stub_request(:get, "https://example.com/rest/api/2/project/project_key").
         with(:headers => {'Accept'=>'application/json', 'User-Agent'=>'Ruby'}).
         to_return(:status => 200, :body => "{\"id\":12345}", :headers => {})

      stub_request(:post, "https://example.com/rest/api/2/issue").
         with(:headers => {'Accept'=>'application/json', 'Content-Type'=>'application/json', 'User-Agent'=>'Ruby'}).
         to_return(:status => 201, :body => "{\"id\":\"foo\",\"key\":\"bar\"}", :headers => {})

      resp = @service.receive_issue_impact_change(@config, @payload)
      expect(resp).to eq({ :jira_story_id => 'foo', :jira_story_key => 'bar' })
    end

    it 'should fail upon unsuccessful api response' do
      stub_request(:get, "https://example.com/rest/api/2/project/project_key").
         with(:headers => {'Accept'=>'application/json', 'User-Agent'=>'Ruby'}).
         to_return(:status => 200, :body => "{\"id\":12345}", :headers => {})

      stub_request(:post, "https://example.com/rest/api/2/issue").
         with(:headers => {'Accept'=>'application/json', 'Content-Type'=>'application/json', 'User-Agent'=>'Ruby'}).
         to_return(:status => 500, :body => "{\"id\":\"foo\"}", :headers => {})

      lambda { @service.receive_issue_impact_change(@config, @payload) }.should raise_error
    end
  end

  describe 'receive_issue_integration_request', :wip => true do
    before do
      @config = { :project_url => 'https://example.com/browse/project_key' }
      @service = Service::Jira.new('issue_integration_request', {})
      @payload = {
        :service_hook => {
          :issue_impact_change => {
            :jira_story_id => 'foo'
          }
        }
      }
      @jira_issue = File.read(File.join(File.dirname(__FILE__), '../', 'fixtures', 'jira_issue.json'))
    end

    it 'should respond' do
      expect(@service.respond_to?(:receive_issue_integration_request)).to be_true
    end

    it 'should succeed upon successful api response' do
      stub_request(:get, "https://example.com/rest/api/2/issue/foo").
        with(:headers => {'Accept'=>'application/json', 'User-Agent'=>'Ruby'}).
        to_return(:status => 200, :body => @jira_issue, :headers => {})

      resp = @service.receive_issue_integration_request(@config, @payload)
      expect(resp).to eq({"id"=>"10105", "key"=>"CRASHES-17", "assignee"=>nil, "created"=>"2014-04-30T16:04:14.634-0700", "creator"=>{"name"=>"user", "emailAddress"=>"user@example.com", "avatarUrls"=>{"16x16"=>"https://example.com/secure/useravatar?size=xsmall&avatarId=10113", "24x24"=>"https://example.com/secure/useravatar?size=small&avatarId=10113", "32x32"=>"https://example.com/secure/useravatar?size=medium&avatarId=10113", "48x48"=>"https://example.com/secure/useravatar?avatarId=10113"}, "displayName"=>"Manuel Deschamps [Administrator]", "active"=>true}, "description"=>"Crashlytics detected a new issue.\\nSLCCG.mm line 198 in -[CrashTestGenerator generateCrashWithKey:]\\n\\nThis issue is affecting at least 1 user who has crashed at least 1 time.\\n\\nMore information: http://vagrant-pipeline/crashlyticsinc/ios/apps/com.crashlytics.ios.crashtest/issues/53617fb6e2fad417dd7f8c48", "issuetype"=>{"id"=>"1", "description"=>"A problem which impairs or prevents the functions of the product.", "iconUrl"=>"https://example.com/images/icons/issuetypes/bug.png", "name"=>"Bug", "subtask"=>false}, "priority"=>{"iconUrl"=>"https://example.com/images/icons/priorities/major.png", "name"=>"Major", "id"=>"3"}, "project"=>{"id"=>"10000", "key"=>"CRASHES", "name"=>"Crashlytics", "avatarUrls"=>{"16x16"=>"https://example.com/secure/projectavatar?size=xsmall&pid=10000&avatarId=10011", "24x24"=>"https://example.com/secure/projectavatar?size=small&pid=10000&avatarId=10011", "32x32"=>"https://example.com/secure/projectavatar?size=medium&pid=10000&avatarId=10011", "48x48"=>"https://example.com/secure/projectavatar?pid=10000&avatarId=10011"}}, "reporter"=>{"name"=>"user", "emailAddress"=>"user@example.com", "avatarUrls"=>{"16x16"=>"https://example.com/secure/useravatar?size=xsmall&avatarId=10113", "24x24"=>"https://example.com/secure/useravatar?size=small&avatarId=10113", "32x32"=>"https://example.com/secure/useravatar?size=medium&avatarId=10113", "48x48"=>"https://example.com/secure/useravatar?avatarId=10113"}, "displayName"=>"Manuel Deschamps [Administrator]", "active"=>true}, "resolution"=>nil, "resolutiondate"=>nil, "status"=>{"description"=>"The issue is open and ready for the assignee to start work on it.", "iconUrl"=>"https://example.com/images/icons/statuses/open.png", "name"=>"Open", "id"=>"1", "statusCategory"=>{"self"=>"https://example.com/rest/api/2/statuscategory/2", "id"=>2, "key"=>"new", "colorName"=>"blue-gray", "name"=>"New"}}, "summary"=>"SLCCG.mm line 198 [Crashlytics]", "updated"=>"2014-04-30T16:04:14.634-0700", "comments"=>[]})
    end

    it 'should fail upon unsuccessful api response' do
      stub_request(:get, "https://example.com/rest/api/2/issue/foo").
         with(:headers => {'Accept'=>'application/json', 'User-Agent'=>'Ruby'}).
         to_return(:status => 500, :body => "", :headers => {})

      resp = @service.receive_issue_integration_request(@config, @payload)
      expect(resp).to be_false
    end
  end

  describe 'issue_resolution_change', :wip => true do
    before do
      @config = { :project_url => 'https://example.com/browse/project_key' }
      @service = Service::Jira.new('issue_resolution_change', {})
      @payload = {
        :service_hook => {
          :issue_impact_change => {
            :jira_story_id => 'foo'
          }
        }
      }
      @jira_issue = File.read(File.join(File.dirname(__FILE__), '../', 'fixtures', 'jira_issue.json'))
    end

    it 'should respond' do
      expect(@service.respond_to?(:receive_issue_resolution_change)).to be_true
    end

    it 'should succeed upon successful api response (resolved)' do
      @payload[:resolved_at] = Time.now.utc

      stub_request(:get, "https://example.com/rest/api/2/issue/foo").
         with(:headers => {'Accept'=>'application/json', 'User-Agent'=>'Ruby'}).
         to_return(:status => 200, :body => @jira_issue, :headers => {})

      stub_request(:post, "https://example.com/rest/api/2/issue/10105/transitions?expand=transitions.fields").
         with(:body => "{\"update\":{\"comment\":[{\"add\":{\"body\":\"This CR has been marked as resolved in Crashlytics\"}}]},\"transition\":{\"id\":\"2\"}}",
              :headers => {'Accept'=>'application/json', 'Content-Type'=>'application/json', 'User-Agent'=>'Ruby'}).
         to_return(:status => 200, :body => "", :headers => {})

      resp = @service.receive_issue_resolution_change(@config, @payload)
      expect(resp["id"]).to eq(JSON.parse(@jira_issue)["id"])
    end

    it 'should succeed upon successful api response (reopened)' do
      @payload[:resolved_at] = nil
      @resolved_issue = JSON.parse(@jira_issue)
      @resolved_issue["fields"]["resolution"] = {:name=>"Fixed"}
      @resolved_issue["fields"]["resolutiondate"] = Time.now.utc

      stub_request(:post, "https://example.com/rest/api/2/issue/10105/transitions?expand=transitions.fields").
         with(:body => "{\"update\":{\"comment\":[{\"add\":{\"body\":\"This CR has been reopened in Crashlytics\"}}]},\"transition\":{\"id\":\"3\"}}",
              :headers => {'Accept'=>'application/json', 'Content-Type'=>'application/json', 'User-Agent'=>'Ruby'}).
         to_return(:status => 200, :body => "", :headers => {})

      stub_request(:get, "https://example.com/rest/api/2/issue/foo").
         with(:headers => {'Accept'=>'application/json', 'User-Agent'=>'Ruby'}).
         to_return(:status => 200, :body => @resolved_issue.to_json, :headers => {})

      resp = @service.receive_issue_resolution_change(@config, @payload)
      expect(resp["resolution"]["name"]).to eq("Fixed")
    end

    it 'should not do anything if statuses are the same (resolved)' do
      @payload[:resolved_at] = Time.now.utc
      @resolved_issue = JSON.parse(@jira_issue)
      @resolved_issue["fields"]["resolution"] = {:name=>"Fixed"}
      @resolved_issue["fields"]["resolutiondate"] = Time.now.utc

      stub_request(:get, "https://example.com/rest/api/2/issue/foo").
         with(:headers => {'Accept'=>'application/json', 'User-Agent'=>'Ruby'}).
         to_return(:status => 200, :body => @resolved_issue.to_json, :headers => {})

      resp = @service.receive_issue_resolution_change(@config, @payload)
      expect(resp).to be_true
    end

    it 'should not do anything if statuses are the same (reopened)' do
      @payload[:resolved_at] = nil

      stub_request(:get, "https://example.com/rest/api/2/issue/foo").
         with(:headers => {'Accept'=>'application/json', 'User-Agent'=>'Ruby'}).
         to_return(:status => 200, :body => @jira_issue, :headers => {})

      resp = @service.receive_issue_resolution_change(@config, @payload)
      expect(resp).to be_true
    end
  end
end
