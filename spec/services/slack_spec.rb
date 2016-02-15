require 'slack-notifier'
require 'spec_helper'

describe Service::Slack do
  let(:config) do
    {
      :url => 'https://crashtest.slack.com/services/hooks/incoming-webhook?token=token',
      :username => 'crashuser',
      :channel => 'mychannel'
    }
  end

  let(:service) { Service::Slack.new(config) }

  it 'has a title' do
    expect(Service::Slack.title).to eq('Slack')
  end

  describe 'schema and display configuration' do
    subject { Service::Slack }

    it { is_expected.to include_string_field :url }
    it { is_expected.to include_string_field :channel }
    it { is_expected.to include_string_field :username}
  end

  describe '#receive_verification' do
    it :success do
      expect(service).to receive(:verification_message)
      expect(service).to receive(:send_message)

      success, message = service.receive_verification
      expect(success).to be true
    end

    it :failure do
      expect(service).to receive(:verification_message)
      expect(service).to receive(:send_message).and_raise

      success, message = service.receive_verification
      expect(success).to be false
    end
  end

  describe '#receive_issue_impact_change' do
    it do
      payload = { :url => 'url', :app => { :name => 'name' },
                  :title => 'title', :method => 'method', :crashes_count => 1}

      expected_attachment = {:fallback=>"Issue #title was created. platform: ",
        :color=>"danger",
        :mrkdwn_in=>["text", "title", "fields", "fallback"],
        :fields=>[{:title=>"Summary", :value=>"Issue #title was created for method method."},
          {:title=>"Platform", :value=>nil, :short=>"true"},
          {:title=>"Bundle identifier", :value=>nil, :short=>"true"}]
      }

      fake_response = double('response', :code => '200', :body => 'Unused')
      expect_any_instance_of(Slack::Notifier).to receive(:ping).
        with('<url|name> crashed 1 times in method!',
          :attachments => [expected_attachment]).and_return(fake_response)

      expect(service.receive_issue_impact_change(payload)).to be :no_resource
    end

    it 'bubbles up errors from Slack' do
      payload = { :url => 'url', :app => { :name => 'name' },
            :title => 'title', :method => 'method', :crashes_count => 1}

      fake_error_response = double('response', :code => '404', :body => 'No service')
      allow_any_instance_of(Slack::Notifier).to receive(:ping).and_return(fake_error_response)

      expect {
        service.receive_issue_impact_change(payload)
      }.to raise_error(/Unexpected response from Slack: 404/)
    end
  end

  describe '#send_message' do
    let(:slack_client) { double(Slack::Notifier) }
    let(:verification_message) do
      "Boom! Crashlytics issue change notifications have been added.  " +
        "<http://support.crashlytics.com/knowledgebase/articles/349341-what-kind-of-third-party-integrations-does-crashly" +
        "|Click here for more info>."
    end

    before do
      allow(Slack::Notifier).to receive(:new)
          .with(config[:url], {:channel=>"mychannel", :username=>"crashuser"})
          .and_return(slack_client)
    end

    it 'treats 200 response as success by returning true and a message' do
      fake_response = double(Net::HTTPResponse, :code => '200', :body => 'foo')
      allow(slack_client).to receive(:ping).with(verification_message, {}).and_return(fake_response)

      success, message = service.receive_verification

      expect(success).to be true
      expect(message).to eq('Successfully sent a message to channel mychannel')
    end

    it 'treats non-200 response as a failure by returning false and an error message' do
      fake_response = double(Net::HTTPResponse, :code => '404', :body => 'foo')
      allow(slack_client).to receive(:ping).with(verification_message, {}).and_return(fake_response)

      success, message = service.receive_verification

      expect(success).to be false
      expect(message).to eq('Could not send a message to channel mychannel. Unexpected response from Slack: 404')
    end
  end
end
