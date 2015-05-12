require 'spec_helper'

describe Service::WebHook do

  it 'has a title' do
    expect(Service::WebHook.title).to eq('Web Hook')
  end

  describe 'schema and display configuration' do
    subject { Service::WebHook }

    it { is_expected.to include_string_field :url }

    it { is_expected.to include_page 'One-Step Setup', [:url] }
  end

  describe 'receive_verification' do
    before do
      @config = { :url => 'https://example.org' }
      @service = Service::WebHook.new('verification', {})
      @payload = {}
    end

    it 'should succeed upon successful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.post('/') { [200, {}, ''] }
        end
      end

      expect(@service).to receive(:http_post)
        .with('https://example.org')
        .and_return(test.post('/'))

      resp = @service.receive_verification(@config, @payload)
      expect(resp).to eq([true,  'Successfully verified Web Hook settings'])
    end

    it 'should fail upon unsuccessful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.post('/') { [500, {}, ''] }
        end
      end

      expect(@service).to receive(:http_post)
        .with('https://example.org')
        .and_return(test.post('/'))

      resp = @service.receive_verification(@config, @payload)
      expect(resp).to eq([false, "Oops! Please check your settings again."])
    end
  end

  describe 'receive_issue_impact_change' do
    before do
      @config = { :url => 'https://example.org' }
      @service = Service::WebHook.new('issue_impact_change', {})
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
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.post('/') { [201, {}, ''] }
        end
      end

      expect(@service).to receive(:http_post)
        .with('https://example.org')
        .and_return(test.post('/'))

      resp = @service.receive_issue_impact_change(@config, @payload)
      expect(resp).to eq(:no_resource)
    end

    it 'should fail with extra information upon unsuccessful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.post('/') { [500, {}, 'fake_body'] }
        end
      end

      expect(@service).to receive(:http_post)
        .with('https://example.org')
        .and_return(test.post('/'))

      expect {
        @service.receive_issue_impact_change(@config, @payload)
      }.to raise_error(/WebHook issue create failed: HTTP status code: 500, body: fake_body/)
    end
  end
end
