require 'spec_helper'
require 'webmock/rspec'

describe Service::Slack, :type => :service do
  let(:config) do
    {
      :url => 'https://crashtest.slack.com/services/hooks/incoming-webhook',
      :username => 'crashuser',
      :channel => 'mychannel'
    }
  end

  let(:logger) { double('fake-logger', :log => nil) }
  let(:service) { Service::Slack.new(config, lambda { |message| logger.log(message) }) }

  it 'has a title' do
    expect(Service::Slack.title).to eq('Slack')
  end

  describe 'schema and display configuration' do
    subject { Service::Slack }

    it { is_expected.to include_string_field :url }
    it { is_expected.to include_string_field :channel }
    it { is_expected.to include_string_field :username}
  end

  def stub_slack_request(options = {})
    expectation_parameters = {
      :headers => { 'Content-Type' => 'application/json' }
    }

    # only set body if it's provided, otherwise skip that check
    expectation_parameters[:body] = options[:request_body]

    stub_request(:post, "https://crashtest.slack.com/services/hooks/incoming-webhook").
      with(expectation_parameters)
  end

  describe '#receive_verification' do
    let(:verification_message) do
      "Boom! Crashlytics issue notifications have been added.  " +
        "<http://support.crashlytics.com/knowledgebase/articles/349341-what-kind-of-third-party-integrations-does-crashly" +
        "|Click here for more info>."
    end
    let(:verification_body) do
      {
        :text => verification_message,
        :channel => 'mychannel',
        :username => 'crashuser'
      }.to_json
    end

    it 'treats 200 response as success' do
      stub_slack_request(:request_body => verification_body).to_return(:status => 200, :body => 'unused')

      service.receive_verification
      expect(logger).to have_received(:log).with('verification successful')
    end

    it 'treats non-200 response as a failure by displaying an error message' do
      stub_slack_request(:request_body => verification_body).to_return(:status => 404, :body => 'unused')

      expect {
        service.receive_verification
      }.to raise_error(Service::DisplayableError, 'Unexpected response from Slack - HTTP status code: 404')
    end
  end

  describe '#receive_issue_impact_change' do
    let(:payload) do
      {
        :url => 'url',
        :display_id => '123',
        :app => { :name => 'name' },
        :title => 'title',
        :method => 'method',
        :crashes_count => 3
      }
    end

    let(:issue_impact_change_attachments) do
      [{
        :fallback => "name crashed 3 times in method!",
        :color => "warning",
        :mrkdwn_in => ["text", "fields"],
        :fields => [
          { :title => "Summary", :value => "Issue #123: title method" },
          { :title => "Platform", :value => nil, :short => true },
          { :title => "Bundle identifier", :value => nil, :short => true }
        ]
      }]
    end
    let(:issue_impact_change_body) do
      {
        :text => '<url|name> crashed 3 times in method!',
        :channel => 'mychannel',
        :username => 'crashuser',
        :attachments => issue_impact_change_attachments
      }.to_json
    end

    it do
      stub_slack_request(:request_body => issue_impact_change_body).to_return(:status => 200, :body => 'unused')

      service.receive_issue_impact_change(payload)
      expect(logger).to have_received(:log).with('issue_impact_change successful')
    end

    it 'bubbles up errors from Slack' do
      stub_slack_request(:request_body => issue_impact_change_body).to_return(:status => 404, :body => 'No service')

      expect {
        service.receive_issue_impact_change(payload)
      }.to raise_error(Service::DisplayableError, 'Unexpected response from Slack - HTTP status code: 404')
    end
  end

  describe '#receive_issue_velocity_alert' do
    let(:payload) do
      {
        :event => 'issue_velocity_alert',
        :display_id => '123',
        :method => 'method',
        :title => 'title',
        :crash_percentage => 1.03,
        :version => '1.0 (1.1)',
        :url => 'url',
        :app => {
          :name => 'AppName',
          :bundle_identifier => 'io.fabric.test',
          :platform => 'platform'
        }
      }
    end
    let(:issue_velocity_alert_attachments) do
      [{
        :fallback => 'Velocity Alert! Issue #123: title method crashed 1.03% of all AppName sessions in the past hour on version 1.0 (1.1)',
        :color => "danger",
        :mrkdwn_in => ["text", "fields"],
        :fields => [
          { :title => "Summary", :value => 'Issue #123: title method' },
          { :title => "Platform", :value => 'platform', :short => true },
          { :title => "Bundle identifier", :value => 'io.fabric.test', :short => true }
        ]
      }]
    end
    let(:issue_velocity_alert_body) do
      {
        :text => 'Velocity Alert! <url|Issue #123: title method> crashed 1.03% of all AppName sessions in the past hour on version 1.0 (1.1)',
        :channel => 'mychannel',
        :username => 'crashuser',
        :attachments => issue_velocity_alert_attachments
      }.to_json
    end

    it 'logs a message on success' do
      stub_slack_request(:request_body => issue_velocity_alert_body).to_return(:status => 200, :body => 'unused')

      service.receive_issue_velocity_alert(payload)
      expect(logger).to have_received(:log).with('issue_velocity_alert successful')
    end

    it 'surfaces failures as human readable error messages' do
      stub_slack_request(:request_body => issue_velocity_alert_body).to_return(:status => 404, :body => 'No service')

      expect {
        service.receive_issue_velocity_alert(payload)
      }.to raise_error(Service::DisplayableError, 'Unexpected response from Slack - HTTP status code: 404')
    end
  end
end
