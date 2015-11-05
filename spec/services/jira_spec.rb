require 'spec_helper'
require 'webmock/rspec'

RSpec.configure do |c|
  c.filter_run_excluding :wip => true
end

describe Service::Jira do

  it 'has a title' do
    expect(Service::Jira.title).to eq('Jira')
  end

  describe 'schema and display configuration' do
    subject { Service::Jira }

    it { is_expected.to include_string_field :project_url }
    it { is_expected.to include_string_field :username }
    it { is_expected.to include_password_field :password }

    it { is_expected.to include_page 'Project', [:project_url] }
    it { is_expected.to include_page 'Login Information', [:username, :password] }
  end

  describe 'receive_verification' do
    before do
      @config = { :project_url => 'https://example.com/browse/project_key' }
      @service = Service::Jira.new('verification', {})
      @payload = {}
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
    before do
      @service = Service::Jira.new('verification', {})
    end

    it 'disables SSL checking when the project_url is http' do
      client = @service.jira_client({ :project_url => 'http://example.com/browse/project_key' }, '')
      expect(client.options[:use_ssl]).to be false
      expect(client.options[:ssl_verify_mode]).to eq(OpenSSL::SSL::VERIFY_NONE)
    end

    it 'enables SSL checking and peer verification when the project_url is https' do
      client = @service.jira_client({ :project_url => 'https://example.com/browse/project_key'}, '')
      expect(client.options[:use_ssl]).to be true
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

      expect {
        @service.receive_issue_impact_change(@config, @payload)
      }.to raise_error(/Jira Issue Create Failed/)
    end
  end

  describe '#parse_url' do
    let(:service) { Service::Jira.new('issue_impact_change', {}) }

    it 'parses old versions of JIRA URLs' do
      parsed = service.parse_url('https://mycompany.atlassian.net/jira/browse/PROJECT-KEY')
      expect(parsed[:url_prefix]).to eq('https://mycompany.atlassian.net')
      expect(parsed[:project_key]).to eq('PROJECT-KEY')
      expect(parsed[:context_path]).to eq('/jira')
    end

    it 'parses new versions of JIRA URLs' do
      parsed = service.parse_url('https://mycompany.atlassian.net/projects/PROJECT-KEY')
      expect(parsed[:url_prefix]).to eq('https://mycompany.atlassian.net')
      expect(parsed[:project_key]).to eq('PROJECT-KEY')
      expect(parsed[:context_path]).to eq('')
    end

    it 'gracefully handles a bogus URL' do
      expect {
        service.parse_url('http://http://http://.com')
      }.to raise_error('Unexpected URL format')
    end
  end
end
