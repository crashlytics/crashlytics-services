require 'spec_helper'
require 'webmock/rspec'

describe Service::WebHook, :type => :service do

  it 'has a title' do
    expect(Service::WebHook.title).to eq('WebHook')
  end

  describe 'schema and display configuration' do
    subject { Service::WebHook }

    it { is_expected.to include_string_field :url }
  end

  let(:logger) { double('fake-logger', :log => nil) }
  let(:config) do
    { :url => 'https://example.org' }
  end
  let(:service) { Service::WebHook.new(config, lambda { |message| logger.log(message) }) }

  describe 'receive_verification' do
    it 'should succeed upon successful api response' do
      stub_request(:post, 'https://example.org?verification=1').
        to_return(:status => 200, :body => 'fake_body')

      service.receive_verification
      expect(logger).to have_received(:log).with('verification successful')
    end

    it 'should fail upon unsuccessful api response' do
      stub_request(:post, 'https://example.org?verification=1').
        to_return(:status => 500, :body => 'fake_body')

      expect {
        service.receive_verification
      }.to raise_error(Service::DisplayableError, 'WebHook verification failed - HTTP status code: 500')
    end
  end

  describe 'receive_issue_impact_change' do
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

    it 'should succeed upon successful api response' do
      stub_request(:post, 'https://example.org').
        to_return(:status => 201, :body => 'fake_body')

      service.receive_issue_impact_change(payload)
      expect(logger).to have_received(:log).with('issue_impact_change successful')
    end

    it 'should fail with extra information upon unsuccessful api response' do
      stub_request(:post, 'https://example.org').
        to_return(:status => 500, :body => 'fake_body')

      expect {
        service.receive_issue_impact_change(payload)
      }.to raise_error(Service::DisplayableError, 'WebHook issue impact change failed - HTTP status code: 500')
    end
  end
end
