require 'spec_helper'

describe Service::Sprintly, :type => :service do
  let(:logger) { double('fake-logger', :log => nil) }
  let(:config) do
    { :dashboard_url => 'https://sprint.ly/product/1/'}
  end
  let(:service) { Service::Sprintly.new(config, lambda { |message| logger.log(message) }) }

  it 'has a title' do
    expect(Service::Sprintly.title).to eq('Sprint.ly')
  end

  describe 'schema and display configuration' do
    subject { Service::Sprintly }

    it { is_expected.to include_string_field :dashboard_url }
    it { is_expected.to include_string_field :email }
    it { is_expected.to include_password_field :api_key}
  end

  describe :receive_verification do
    it 'should succeed upon successful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.get('/api/products/1/items.json') { [200, {}, ''] }
        end
      end

      expect(service).to receive(:http_get)
        .with('https://sprint.ly/api/products/1/items.json')
        .and_return(test.get('/api/products/1/items.json'))

      service.receive_verification
      expect(logger).to have_received(:log).with('verification successful')
    end

    it 'should fail upon unsuccessful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.get('/api/products/1/items.json') { [500, {}, ''] }
        end
      end

      expect(service).to receive(:http_get)
        .with('https://sprint.ly/api/products/1/items.json')
        .and_return(test.get('/api/products/1/items.json'))

      expect {
        service.receive_verification
      }.to raise_error(Service::DisplayableError, 'Sprint.ly error - HTTP status code: 500')
    end
  end

  describe :receive_issue_impact_change do
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
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.post('/api/products/1/items.json') { [200, {}, { number: '42' }.to_json] }
          stub.get('/api/products/1/items.json') { [200, {}, ""] }
        end
      end

      expect(service).to receive(:http_post)
        .with('https://sprint.ly/api/products/1/items.json')
        .and_return(test.post('/api/products/1/items.json'))

      service.receive_issue_impact_change(payload)
      expect(logger).to have_received(:log).with('issue_impact_change successful')
    end

    it 'should fail upon unsuccessful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.post('/api/products/1/items.json') { [500, {}, ""] }
          stub.get('/api/products/1/items.json') { [200, {}, ""] }
        end
      end

      expect(service).to receive(:http_post)
        .with('https://sprint.ly/api/products/1/items.json')
        .and_return(test.post('/api/products/1/items.json'))

      expect {
        service.receive_issue_impact_change(payload)
      }.to raise_error(Service::DisplayableError, '[Sprint.ly] Adding defect to backlog failed - HTTP status code: 500')
    end
  end
end
