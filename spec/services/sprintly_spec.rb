require 'spec_helper'

describe Service::Sprintly do

  it 'has a title' do
    expect(Service::Sprintly.title).to eq('Sprint.ly')
  end

  describe 'schema and display configuration' do
    subject { Service::Sprintly }

    it { is_expected.to include_string_field :dashboard_url }
    it { is_expected.to include_string_field :email }
    it { is_expected.to include_password_field :api_key}

    it { is_expected.to include_page 'Product', [:dashboard_url] }
    it { is_expected.to include_page 'Login Information', [:email, :api_key] }
  end

  describe :receive_verification do
    let(:service) { Service::Sprintly.new('event_name', {}) }
    let(:config) do
      {
        :dashboard_url => 'https://sprint.ly/product/1/'
      }
    end
    let(:payload) { {} }

    it 'should succeed upon successful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.get('/api/products/1/items.json') { [200, {}, ''] }
        end
      end

      expect(service).to receive(:http_get)
        .with('https://sprint.ly/api/products/1/items.json')
        .and_return(test.get('/api/products/1/items.json'))

      resp = service.receive_verification(config, payload)
      expect(resp).to eq([true, 'Successfully verified Sprint.ly settings!'])
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

      resp = service.receive_verification(config, payload)
      expect(resp).to eq([false, 'Oops! Please check your settings again.'])
    end
  end

  describe :receive_issue_impact_change do
    let(:service) { Service::Sprintly.new('event_name', {}) }
    let(:config) do
      {
        :dashboard_url => 'https://sprint.ly/product/1/'
      }
    end
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

      resp = service.receive_issue_impact_change(config, payload)
      expect(resp).to eq(:sprintly_item_number => '42')
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

      expect { service.receive_issue_impact_change(config, payload) }.to raise_error(/Adding defect to backlog failed/)
    end
  end
end
