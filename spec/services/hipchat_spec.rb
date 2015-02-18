require 'hipchat'
require 'spec_helper'

describe Service::HipChat do
  let(:config) do
    {
      :api_token => 'token',
      :room => 'room id',
      :notify => nil
    }
  end

  it 'should have a title' do
    Service::HipChat.title.should == 'HipChat'
  end

  describe :receive_verification do
    it :success do
      service = Service::HipChat.new('verification', {})
      service.should_receive(:receive_verification_message)
      service.should_receive(:send_message)

      success, message = service.receive_verification(config, nil)
      success.should be true
    end

    it :failure do
      service = Service::HipChat.new('verification', {})
      service.should_receive(:receive_verification_message)
      service.should_receive(:send_message).and_raise

      success, message = service.receive_verification(config, nil)
      success.should be false
    end
  end

  describe :receive_issue_impact_change do
    it do
      payload = { :url => 'url', :app => { :name => 'name' }, 
                  :title => 'title', :method => 'method' }
      service = Service::HipChat.new('issue_impact_change', {})
      service.should_receive(:format_issue_impact_change_message).with(payload)
      service.should_receive(:send_message)

      service.receive_issue_impact_change(config, payload).should == :no_resource
    end
  end

  describe :send_message do
    it do
      message = 'hi'
      client = double(HipChat::Client)
      options = { :api_version => 'v1' }
      HipChat::Client.should_receive(:new).with(config[:api_token], options).and_return(client)
      client.should_receive(:[]).with(config[:room]).and_return(client)
      client.should_receive(:send).with('Crashlytics', message, { :notify => false })

      Service::HipChat.new('verification', {}).send(:send_message, config, message)
    end
  end
end
