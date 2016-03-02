require 'spec_helper'
require 'webmock/rspec'

describe Service::Campfire, :type => :service do
  before do
    @config = { :subdomain => "crashlytics",
                :room => "crashlytics-test",
                :api_token => "api_token" }

    @logger = double('fake-logger', :log => nil)
    @service = Service::Campfire.new(@config, lambda { |message| @logger.log message })
  end

  it 'has a title' do
    expect(Service::Campfire.title).to eq('Campfire')
  end

  describe 'schema and display configuration' do
    subject { Service::Campfire }

    it { is_expected.to include_string_field :subdomain }
    it { is_expected.to include_string_field :room }
    it { is_expected.to include_password_field :api_token }
  end

  describe 'receive_verification' do
    it 'should succeed upon successful api response' do
      stub_request(:get, "https://api_token:@crashlytics.campfirenow.com/rooms").
        to_return(:status => 200, :body => '{"rooms":[{"id":620593,"name":"crashlytics-test"}]}', :headers => {})
      @service.receive_verification
      expect(@logger).to have_received(:log).with('verification successful')
    end

    it 'should fail upon unsuccessful api response' do
      stub_request(:get, "https://api_token:@crashlytics.campfirenow.com/rooms").
        to_return(:status => 401, :body => "", :headers => {})
      expect {
        @service.receive_verification
      }.to raise_error(Service::DisplayableError, "Oops! Can not find #{@config[:room]} room. Please check your settings.")
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
        },
        :url => "http://foo.com/bar"
      }
      stub_request(:get, "https://api_token:@crashlytics.campfirenow.com/rooms").
        to_return(:status => 200, :body => '{"rooms":[{"id":620593,"name":"crashlytics-test"}]}', :headers => {})
    end

    it 'should succeed upon successful api response' do
      stub_request(:post, "https://api_token:@crashlytics.campfirenow.com/room/620593/speak").
        to_return(:status => 200, :body => '', :headers => {})

      @service.receive_issue_impact_change(@payload)
    end

    it 'should fail upon unsuccessful api response' do
      stub_request(:post, "https://api_token:@crashlytics.campfirenow.com/room/620593/speak").
        to_return(:status => 401, :body => '', :headers => {})

      expect {
        @service.receive_issue_impact_change(@payload)
      }.to raise_error(Service::DisplayableError, /Could not send Campfire message/)
    end
  end
end
