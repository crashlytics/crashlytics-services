require 'spec_helper'

describe Service::Appaloosa do

  let(:web_hook_url) { 'https://www.appaloosa-store.com/123-fake-store/mobile_applications/456/issues?application_token=4d9b0a249ff0b82d47ab12394edd64c202d32edb6d9c44e5993bb38a8be345ca' }

  it 'has a title' do
    expect(Service::Appaloosa.title).to eq('Appaloosa')
  end

  describe 'schema and display configuration' do
    subject { Service::Appaloosa }

    it { is_expected.to include_string_field :url }
    it { is_expected.to include_page 'URL', [:url] }
  end

  describe 'receive_verification' do
    before do
      @config = { :url => web_hook_url }
      @service = Service::Appaloosa.new('verification', {})
      @payload = {}
    end

    it 'should succeed upon successful api response' do
      stub_request(:post, "#{web_hook_url}&verification=1").
        to_return(:status => 200, :body => 'fake_body')

      resp = @service.receive_verification(@config, @payload)
      expect(resp).to eq([true,  'Successfully sent a message to Appaloosa'])
    end

    it 'should fail upon unsuccessful api response' do
      stub_request(:post, "#{web_hook_url}&verification=1").
        to_return(:status => 500, :body => 'fake_body')

      resp = @service.receive_verification(@config, @payload)
      expect(resp).to eq([false, "Could not send a message to Appaloosa"])
    end
  end

  describe 'receive_issue_impact_change' do
    before do
      @config = { :url => web_hook_url }
      @service = Service::Appaloosa.new('issue_impact_change', {})
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

      resp = @service.receive_issue_impact_change(@config, @payload)
      expect(resp).to eq(:no_resource)
    end

    it 'should fail with extra information upon unsuccessful api response' do
      stub_request(:post, web_hook_url).
        to_return(:status => 500, :body => 'fake_body')

      expect {
        @service.receive_issue_impact_change(@config, @payload)
      }.to raise_error('Appaloosa WebHook issue create failed - HTTP status code: 500, body: fake_body')
    end

    it 'suppresses the body of a failed api response if it appears to be an HTML document' do
      stub_request(:post, web_hook_url).
        to_return(:status => 500, :body => '<!DOCTYPE html><html><body>Stuff</body></html>')

      expect {
        @service.receive_issue_impact_change(@config, @payload)
      }.to raise_error('Appaloosa WebHook issue create failed - HTTP status code: 500')
    end
  end
end
