require 'spec_helper'

describe Service::Appaloosa do

  let(:web_hook_url) { 'https://www.appaloosa-store.com/123-fake-store/mobile_applications/456/issues?application_token=4d9b0a249ff0b82d47ab12394edd64c202d32edb6d9c44e5993bb38a8be345ca' }

  before do
    @config = { :url => web_hook_url }
    @service = Service::Appaloosa.new(@config)
  end

  it 'has a title' do
    expect(Service::Appaloosa.title).to eq('Appaloosa')
  end

  describe 'schema and display configuration' do
    subject { Service::Appaloosa }

    it { is_expected.to include_string_field :url }
  end

  describe 'receive_verification' do
    it 'should succeed upon successful api response' do
      stub_request(:post, "#{web_hook_url}&verification=1").
        to_return(:status => 200, :body => 'fake_body')

      resp = @service.receive_verification
      expect(resp).to eq([true,  'Successfully sent a message to Appaloosa'])
    end

    it 'should fail upon unsuccessful api response' do
      stub_request(:post, "#{web_hook_url}&verification=1").
        to_return(:status => 500, :body => 'fake_body')

      resp = @service.receive_verification
      expect(resp).to eq([false, "Could not send a message to Appaloosa"])
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
      stub_request(:post, web_hook_url).
        to_return(:status => 201, :body => 'fake_body')

      resp = @service.receive_issue_impact_change(@payload)
    end

    it 'should fail with extra information upon unsuccessful api response' do
      stub_request(:post, web_hook_url).
        to_return(:status => 500, :body => 'fake_body')

      expect {
        @service.receive_issue_impact_change(@payload)
      }.to raise_error('Appaloosa WebHook issue create failed - HTTP status code: 500')
    end
  end
end
