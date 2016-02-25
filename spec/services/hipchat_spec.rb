require 'hipchat'
require 'spec_helper'

describe Service::HipChat, :type => :service do
  let(:config) do
    {
      :api_token => 'token',
      :room => 'room id',
      :notify => nil
    }
  end
  let(:logger) { double('fake-logger', :log => nil) }
  let(:service) { Service::HipChat.new(config, lambda { |message| logger.log(message) }) }

  it 'has a title' do
    expect(Service::HipChat.title).to eq('HipChat')
  end

  describe 'schema and display configuration' do
    subject { Service::HipChat }

    it { is_expected.to include_string_field :api_token }
    it { is_expected.to include_checkbox_field :v2 }
    it { is_expected.to include_string_field :room }
    it { is_expected.to include_checkbox_field :notify }
    it { is_expected.to include_string_field :url }
  end

  describe :receive_verification do
    it :success do
      expect(service).to receive(:verification_message)
      expect(service).to receive(:send_message)

      service.receive_verification
      expect(logger).to have_received(:log).with('verification successful')
    end

    it :failure do
      expect(service).to receive(:verification_message)
      expect(service).to receive(:send_message).and_raise

      expect {
        service.receive_verification
      }.to raise_error(Service::DisplayableError, 'Could not send a message to room room id')
    end
  end

  describe :receive_issue_impact_change do
    it do
      payload = { :url => 'url', :app => { :name => 'name' },
                  :title => 'title', :method => 'method' }
      expect(service).to receive(:format_issue_impact_change_message).with(payload)
      expect(service).to receive(:send_message)

      service.receive_issue_impact_change(payload)
      expect(logger).to have_received(:log).with('issue_impact_change successful')
    end

    it 'surfaces exceptions as runtime errors' do
      payload = { :url => 'url', :app => { :name => 'name' },
            :title => 'title', :method => 'method' }

      expect(service).to receive(:send_message).and_raise('Unhandled error')

      expect {
        service.receive_issue_impact_change(payload)
      }.to raise_error(/Unhandled error/)
    end
  end
end
