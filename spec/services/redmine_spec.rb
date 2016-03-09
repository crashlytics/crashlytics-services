require 'spec_helper'
require 'webmock/rspec'

describe Service::Redmine, :type => :service do

  it 'has a title' do
    expect(Service::Redmine.title).to eq('Redmine')
  end

  before do
    @logger = double('fake-logger', :log => nil)
    @config = { :project_url => 'http://redmine.acme.com/projects/foo_project' }
    @service = Service::Redmine.new(@config, lambda { |message| @logger.log(message) })
  end

  describe 'schema and display configuration' do
    subject { Service::Redmine }

    it { is_expected.to include_string_field :project_url }
    it { is_expected.to include_password_field :api_key }
  end

  describe 'receive_verification' do

    it 'should succeed upon successful api response' do
      stub_request(:get, "http://redmine.acme.com/issues.json?key&limit=1&project_id=foo_project").
        to_return(:status => 200, :body => "", :headers => {})

      @service.receive_verification
      expect(@logger).to have_received(:log).with('verification successful')
    end

    it 'should fail upon unsuccessful api response' do
      stub_request(:get, 'http://redmine.acme.com/issues.json?key&limit=1&project_id=foo_project').
        to_return(:status => 500, :body => 'body-text')

      expect {
        @service.receive_verification
      }.to raise_error(Service::DisplayableError, 'Unexpected response from Redmine - HTTP status code: 500')
    end
  end

  describe 'receive_issue_impact_change' do
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
      stub_body = { :issue => { :id => 'foo_id' }}
      stub_request(:post, "http://redmine.acme.com/issues.json?key").
        to_return(:status => 201, :body => stub_body.to_json)

      @service.receive_issue_impact_change(@payload)
      expect(@logger).to have_received(:log).with('issue_impact_change successful')
    end

    it 'should fail upon unsuccessful api response' do
      stub_request(:post, "http://redmine.acme.com/issues.json?key").
        to_return(:status => 500, :body => "", :headers => {})

      expect {
        @service.receive_issue_impact_change(@payload)
      }.to raise_error(Service::DisplayableError, 'Redmine Issue Create Failed - HTTP status code: 500')
    end
  end
end
