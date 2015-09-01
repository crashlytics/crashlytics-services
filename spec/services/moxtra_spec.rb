require 'spec_helper'

describe Service::Moxtra do

  it 'has a title' do
    expect(Service::Moxtra.title).to eq('Moxtra')
  end

  describe 'schema and display configuration' do
    subject { Service::Moxtra }

    it { is_expected.to include_string_field :url }

    it { is_expected.to include_page 'URL', [:url] }
  end

  describe 'receive_verification' do
    before do
      @config = { :url => 'https://api.moxtra.com/webhooks/CAEqBTAvMWdpehdCcW96c1Y0QVEwNjh6ZkZ6VHZPTkFqMIABBpADFA' }
      @service = Service::Moxtra.new('verification', {})
      @payload = {}
    end

    it 'should succeed upon successful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.post('/') { [200, {}, ''] }
        end
      end

      expect(@service).to receive(:http_post)
        .with('https://api.moxtra.com/webhooks/CAEqBTAvMWdpehdCcW96c1Y0QVEwNjh6ZkZ6VHZPTkFqMIABBpADFA')
        .and_return(test.post('/'))

      resp = @service.receive_verification(@config, @payload)
      expect(resp).to eq([true,  "Successfully sent a message to Moxtra binder"])
    end

    it 'should fail upon unsuccessful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.post('/') { [500, {}, ''] }
        end
      end

      expect(@service).to receive(:http_post)
        .with('https://api.moxtra.com/webhooks/CAEqBTAvMWdpehdCcW96c1Y0QVEwNjh6ZkZ6VHZPTkFqMIABBpADFA')
        .and_return(test.post('/'))

      resp = @service.receive_verification(@config, @payload)
      expect(resp).to eq([false, "Could not send a message to Moxtra binder"])
    end
  end

  describe 'receive_issue_impact_change' do
    before do
      @config = { :url => 'https://api.moxtra.com/webhooks/CAEqBTAvMWdpehdCcW96c1Y0QVEwNjh6ZkZ6VHZPTkFqMIABBpADFA' }
      @service = Service::Moxtra.new('issue_impact_change', {})
      @payload = {
        :title => 'title',
        :impact_level => 1,
        :impacted_devices_count => 1,
        :crashes_count => 1,
        :app => {
          :name => 'name',
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
        .with('https://api.moxtra.com/webhooks/CAEqBTAvMWdpehdCcW96c1Y0QVEwNjh6ZkZ6VHZPTkFqMIABBpADFA')
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
        .with('https://api.moxtra.com/webhooks/CAEqBTAvMWdpehdCcW96c1Y0QVEwNjh6ZkZ6VHZPTkFqMIABBpADFA')
        .and_return(test.post('/'))

      expect {
        @service.receive_issue_impact_change(@config, @payload)
      }.to raise_error(/Moxtra WebHook issue create failed: HTTP status code: 500, body: fake_body/)
    end
  end
end
