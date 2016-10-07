require 'spec_helper'
require 'webmock/rspec'

describe Service::Redmine, :type => :service do

  it 'has a title' do
    expect(Service::Redmine.title).to eq('Redmine')
  end

  before do
    @logger = double('fake-logger', :log => nil)
    @config = { :project_url => 'http://redmine.acme.com/projects/foo_project', :api_key => '123456' }
    @service = Service::Redmine.new(@config, lambda { |message| @logger.log(message) })
  end

  describe 'schema and display configuration' do
    subject { Service::Redmine }

    it { is_expected.to include_string_field :project_url }
    it { is_expected.to include_password_field :api_key }
    it { is_expected.to include_string_field :project_id }
    it { is_expected.to include_string_field :tracker_id }
    it { is_expected.to include_string_field :status_id }
  end

  describe 'receive_verification' do

    it 'should succeed upon successful api response' do
      stub_request(:get, "http://redmine.acme.com/issues.json?key=123456&limit=1&project_id=foo_project").
        to_return(:status => 200, :body => "", :headers => {})

      @service.receive_verification
      expect(@logger).to have_received(:log).with('verification successful')
    end

    it 'should fail upon unsuccessful api response' do
      stub_request(:get, 'http://redmine.acme.com/issues.json?key=123456&limit=1&project_id=foo_project').
        to_return(:status => 500, :body => 'body-text')

      expect {
        @service.receive_verification
      }.to raise_error(Service::DisplayableError, 'Unexpected response from Redmine - HTTP status code: 500')
    end
  end

  describe 'receive_issue_impact_change' do
    def issue_creation_url
      'http://redmine.acme.com/issues.json?key=123456'
    end

    def stub_issue_creation
      stub_request(:post, issue_creation_url)
    end

    def stubbed_response_body
      { :issue => { :id => 'foo_id' }}
    end

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
      stub_issue_creation.to_return(:status => 201, :body => stubbed_response_body.to_json)

      @service.receive_issue_impact_change(@payload)
      expect(@logger).to have_received(:log).with('issue_impact_change successful')

      expect(WebMock).not_to have_requested(:post, issue_creation_url).with(:body => /tracker_id/)
      expect(WebMock).not_to have_requested(:post, issue_creation_url).with(:body => /status_id/)
    end

    it 'should fail upon unsuccessful api response' do
      stub_issue_creation.to_return(:status => 500, :body => "", :headers => {})

      expect {
        @service.receive_issue_impact_change(@payload)
      }.to raise_error(Service::DisplayableError, 'Redmine Issue Create Failed - HTTP status code: 500')
    end

    it 'defaults the project_id to the project name in the url path if not configured' do
      stub_issue_creation.with(:body => /\"project_id\":\"foo_project\"/).
        to_return(:status => 201, :body => stubbed_response_body.to_json)

      @service.receive_issue_impact_change(@payload)
      expect(@logger).to have_received(:log).with('issue_impact_change successful')
    end

    it 'provides the project_id param if configured' do
      @service = Service::Redmine.new(@config.merge(:project_id => '99999'), lambda { |message| @logger.log(message) })

      stub_issue_creation.with(:body => /\"project_id\":\"99999\"/).
        to_return(:status => 201, :body => stubbed_response_body.to_json)

      @service.receive_issue_impact_change(@payload)
      expect(@logger).to have_received(:log).with('issue_impact_change successful')
    end

    it 'provides the tracker_id param if configured' do
      @service = Service::Redmine.new(@config.merge(:tracker_id => '0'), lambda { |message| @logger.log(message) })

      stub_issue_creation.with(:body => /\"tracker_id\":\"0\"/).
        to_return(:status => 201, :body => stubbed_response_body.to_json)

      @service.receive_issue_impact_change(@payload)
      expect(@logger).to have_received(:log).with('issue_impact_change successful')
    end

    it 'provides the status_id param if configured' do
      @service = Service::Redmine.new(@config.merge(:status_id => '0'), lambda { |message| @logger.log(message) })

      stub_issue_creation.with(:body => /\"status_id\":\"0\"/).
        to_return(:status => 201, :body => stubbed_response_body.to_json)

      @service.receive_issue_impact_change(@payload)
      expect(@logger).to have_received(:log).with('issue_impact_change successful')
    end
  end
end
