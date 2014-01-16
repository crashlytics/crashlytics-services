require 'spec_helper'

describe Service::Sprintly do
  it 'should have a title' do
    Service::Sprintly.title.should == 'Sprint.ly'
  end

  describe :receive_verification do
    let(:service) { Service::Sprintly.new('event_name', {}) }
    let(:config) do
      {
        :dashboard_url => 'https://sprint.ly/product/1/'
      }
    end
    let(:payload) { {} }

    it 'should respond' do
      service.respond_to?(:receive_verification)
    end

    it 'should succeed upon successful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.get('/api/products/1/items.json') { [200, {}, ''] }
        end
      end

      service.should_receive(:http_get)
        .with('https://sprint.ly/api/products/1/items.json')
        .and_return(test.get('/api/products/1/items.json'))

      resp = service.receive_verification(config, payload)
      resp.should == [true, 'Successfully verified Sprint.ly settings!']
    end

    it 'should fail upon unsuccessful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.get('/api/products/1/items.json') { [500, {}, ''] }
        end
      end

      service.should_receive(:http_get)
        .with('https://sprint.ly/api/products/1/items.json')
        .and_return(test.get('/api/products/1/items.json'))

      resp = service.receive_verification(config, payload)
      resp.should == [false, 'Oops! Please check your settings again.']
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

    it 'should respond to receive_issue_impact_change' do
      service.respond_to?(:receive_issue_impact_change)
    end

    it 'should succeed upon successful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.post('/api/products/1/items.json') { [200, {}, { number: '42' }.to_json] }
          stub.get('/api/products/1/items.json') { [200, {}, ""] }
        end
      end

      service.should_receive(:http_post)
        .with('https://sprint.ly/api/products/1/items.json')
        .and_return(test.post('/api/products/1/items.json'))

      resp = service.receive_issue_impact_change(config, payload)
      resp.should == { :sprintly_item_number => '42' }
    end

    it 'should fail upon unsuccessful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.post('/api/products/1/items.json') { [500, {}, ""] }
          stub.get('/api/products/1/items.json') { [200, {}, ""] }
        end
      end

      service.should_receive(:http_post)
        .with('https://sprint.ly/api/products/1/items.json')
        .and_return(test.post('/api/products/1/items.json'))

      lambda { service.receive_issue_impact_change(config, payload) }.should raise_error
    end
  end
end
