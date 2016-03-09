require 'spec_helper'
require 'webmock/rspec'

describe Service::GitHub, :type => :service do
  let(:config) do
    {
      :access_token => 'foo_access_token',
      :repo => 'crashlytics/sample-project'
    }
  end

  let(:logger) { double('fake-logger', :log => nil) }
  let(:logger_function) { lambda { |message| logger.log(message) }}
  let(:service) { Service::GitHub.new(config, logger_function) }

  it 'has a title' do
    expect(Service::GitHub.title).to eq('GitHub')
  end

  describe 'schema and display configuration' do
    subject { Service::GitHub }

    it { is_expected.to include_string_field :api_endpoint }
    it { is_expected.to include_string_field :repo }
    it { is_expected.to include_password_field :access_token }
  end

  describe '#receive_verification' do
    it 'returns true and a confirmation message on success' do
      stub_request(:get, 'https://api.github.com/repos/crashlytics/sample-project').
         to_return(:status => 200, :body => '')

      service.receive_verification
      expect(logger).to have_received(:log).with('verification successful')
    end

    it 'returns false and an error message on failure' do
      stub_request(:get, 'https://api.github.com/repos/crashlytics/sample-project').
         to_return(:status => 404, :body => '')

      expect {
        service.receive_verification
      }.to raise_error(Service::DisplayableError, 'Could not access repository for crashlytics/sample-project.')
    end

    it 'uses the api_endpoint if provided' do
      service = Service::GitHub.new(config.merge(:api_endpoint => 'https://github.fabric.io/api/v3'), logger_function)

      stub_request(:get, 'https://github.fabric.io/api/v3/repos/crashlytics/sample-project').
        to_return(:status => 200, :body => '')

      service.receive_verification
      expect(logger).to have_received(:log).with('verification successful')
    end
  end

  describe '#receive_issue_impact_change' do
    let(:crashlytics_issue) do
      {
        :url => 'foo_issue_url',
        :app => { :name => 'foo_app_name' },
        :title => 'foo_issue_title',
        :method => 'foo_issue_method',
        :crashes_count => 'foo_issue_crashes_count',
        :impacted_devices_count => 'foo_issue_impacted_devices_count'
      }
    end
    let(:expected_issue_body) do
      "#### in foo_issue_method\n" \
      "\n" \
      "* Number of crashes: foo_issue_crashes_count\n" \
      "* Impacted devices: foo_issue_impacted_devices_count\n" \
      "\n" \
      "There's a lot more information about this crash on crashlytics.com:\n" \
      "[foo_issue_url](foo_issue_url)"
    end

    let(:successful_creation_response) do
      {
        :status => 201,
        :headers => { 'content-type' => 'application/json' },
        :body => { :id => 743, :number => 42 }.to_json
      }
    end

    let(:failed_creation_response) do
      {
        :status => 401,
        :headers => { 'content-type' => 'application/json'},
        :body => { :message => 'GitHub error message' }.to_json
      }
    end

    it 'creates a new GitHub issue' do
      stub_request(:post, 'https://api.github.com/repos/crashlytics/sample-project/issues').
        to_return(successful_creation_response)

      service.receive_issue_impact_change(crashlytics_issue)
      expect(logger).to have_received(:log).with('issue_impact_change successful')
    end

    it 'creates a new Github issue on an enterprise account if api_endpoint is provided' do
      service = Service::GitHub.new(config.merge(:api_endpoint => 'https://github.fabric.io/api/v3'), logger_function)

      stub_request(:post, 'https://github.fabric.io/api/v3/repos/crashlytics/sample-project/issues').
        to_return(successful_creation_response)

      service.receive_issue_impact_change(crashlytics_issue)
      expect(logger).to have_received(:log).with('issue_impact_change successful')
    end

    it 'raises if creating a new GitHub issue fails' do
      stub_request(:post, 'https://api.github.com/repos/crashlytics/sample-project/issues').
        to_return(failed_creation_response)

      expect { service.receive_issue_impact_change crashlytics_issue }.
        to raise_error(Service::DisplayableError)
    end
  end
end
