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
      "Boom! Crashlytics issue change notifications have been added.  " +
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
    let(:issue_impact_change_attachments) do
      [{
        :fallback => "Issue #title was created. platform: ",
        :color => "danger",
        :mrkdwn_in => ["text", "title", "fields", "fallback"],
        :fields => [
          { :title => "Summary", :value => "Issue #title was created for method method." },
          { :title => "Platform", :value => nil, :short => "true" },
          { :title => "Bundle identifier", :value => nil, :short => "true"}
        ]
      }]
    end
    let(:issue_impact_change_body) do
      {
        :text => '<url|name> crashed 1 times in method!',
        :channel => 'mychannel',
        :username => 'crashuser',
        :attachments => issue_impact_change_attachments
      }.to_json
    end

    it do
      stub_slack_request(:request_body => issue_impact_change_body).to_return(:status => 200, :body => 'unused')

      payload = { :url => 'url', :app => { :name => 'name' },
                  :title => 'title', :method => 'method', :crashes_count => 1}

      service.receive_issue_impact_change(payload)
      expect(logger).to have_received(:log).with('issue_impact_change successful')
    end

    it 'bubbles up errors from Slack' do
      stub_slack_request(:request_body => issue_impact_change_body).to_return(:status => 404, :body => 'No service')

      payload = { :url => 'url', :app => { :name => 'name' },
            :title => 'title', :method => 'method', :crashes_count => 1}

      expect {
        service.receive_issue_impact_change(payload)
      }.to raise_error(Service::DisplayableError, 'Unexpected response from Slack - HTTP status code: 404')
    end
  end
end
