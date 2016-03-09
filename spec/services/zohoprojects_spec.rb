require 'spec_helper'
require 'webmock/rspec'

describe Service::ZohoProjects, :type => :service do

  let(:logger) { double('fake-logger', :log => nil) }
  let(:config) do
    {
      :project_id => 'sample_project_id',
      :authtoken => 'sample_authtoken'
    }
  end
  let(:service) do
    Service::ZohoProjects.new(config, lambda { |message| logger.log(message) })
  end

  it 'has a title' do
    expect(Service::ZohoProjects.title).to eq('Zoho Projects')
  end

  describe 'schema and display configuration' do
    subject { Service::ZohoProjects }

    it { is_expected.to include_string_field :project_id }
    it { is_expected.to include_password_field :authtoken }
  end

  def stub_api_call(expected_query)
    stub_request(:post, 'https://projectsapi.zoho.com/serviceHook').with(:query => expected_query)
  end

  describe '#receive_verification' do
    let(:expected_query) do
      {
        :authtoken => 'sample_authtoken',
        :pId => 'sample_project_id',
        :pltype => 'chook',
        :payload => { :event => 'verification' }.to_json
      }
    end

    it 'a non-400 response as a success' do
      stub_api_call(expected_query).to_return(:status => 200)

      service.receive_verification
      expect(service.http.ssl[:verify]).to be true # mark ssl for verification
      expect(logger).to have_received(:log).with('verification successful')
    end

    it 'escalates a 400 response as a failure' do
      stub_api_call(expected_query).to_return(:status => 400)

      expect {
        service.receive_verification
      }.to raise_error(Service::DisplayableError, 'Invalid Auth Token/Project ID')
    end

    it 'escalates a 400 response as a failure' do
      stub_api_call(expected_query).to_return(:status => 500)

      expect {
        service.receive_verification
      }.to raise_error(Service::DisplayableError, 'ZohoProjects verification failed - HTTP status code: 500')
    end
  end

  describe '#receive_issue_impact_change' do
    let(:payload) do
      {
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

    let(:expected_query) do
      {
        :authtoken => 'sample_authtoken',
        :pId => 'sample_project_id',
        :pltype => 'chook',
        :payload => { :event => 'issue_impact_change', :payload => payload }.to_json
      }
    end

    it 'creates a new issue and return its true on success' do
      stub_api_call(expected_query).to_return(:status => 200, :body => 'fake-zoho-bug-id')

      response = service.receive_issue_impact_change(payload)

      expect(service.http.ssl[:verify]).to be true # mark ssl for verification
      expect(logger).to have_received(:log).with('issue_impact_change successful')
    end

    it 'escalates non-200 response codes as an error' do
      stub_api_call(expected_query).to_return(:status => 400, :body => 'fake-error-body')

      expect {
        service.receive_issue_impact_change(payload)
      }.to raise_error(Service::DisplayableError, 'Problem while sending request to Zoho Projects - HTTP status code: 400')
    end
  end
end
