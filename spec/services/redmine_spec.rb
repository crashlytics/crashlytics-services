require 'spec_helper'

describe Service::Redmine do

  it 'has a title' do
    expect(Service::Redmine.title).to eq('Redmine')
  end

  describe 'schema and display configuration' do
    subject { Service::Redmine }

    it { is_expected.to include_string_field :project_url }
    it { is_expected.to include_string_field :api_key }

    it { is_expected.to include_page 'Project', [:project_url] }
    it { is_expected.to include_page 'API Key', [:api_key] }
  end

  describe 'receive_verification' do
    before do
      @config = { :project_url => 'http://redmine.acme.com/projects/foo_project' }
      @service = Service::Redmine.new('verification', {})
      @payload = {}
    end

    it 'should succeed upon successful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.get('/issues.json') { [200, {}, ''] }
        end
      end

      expect(@service).to receive(:http_get)
        .with('http://redmine.acme.com/issues.json', { :key => nil, :project_id => "foo_project", :limit => 1 })
        .and_return(test.get('/issues.json'))

      resp = @service.receive_verification(@config, @payload)
      expect(resp).to eq([true,  "Successfully verified Redmine settings"])
    end

    it 'should fail upon unsuccessful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.get('/issues.json') { [500, {}, ''] }
        end
      end

      expect(@service).to receive(:http_get)
        .with('http://redmine.acme.com/issues.json', { :key => nil, :project_id => "foo_project", :limit => 1 })
        .and_return(test.get('/issues.json'))

      resp = @service.receive_verification(@config, @payload)
      expect(resp).to eq([false, "Oops! Please check your settings again."])
    end
  end

  describe 'receive_issue_impact_change' do
    before do
      @config = { :project_url => 'http://redmine.acme.com/projects/foo_project' }
      @service = Service::Redmine.new('issue_impact_change', {})
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
          stub.post('/issues.json') { [201, {}, "{\"issue\":{\"id\":\"foo_id\"}}"] }
        end
      end

      expect(@service).to receive(:http_post)
        .with('http://redmine.acme.com/issues.json')
        .and_return(test.post('/issues.json'))

      resp = @service.receive_issue_impact_change(@config, @payload)
      expect(resp).to eq(:redmine_issue_id => 'foo_id')
    end

    it 'should fail upon unsuccessful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.post('/issues.json') { [500, {}, "{\"issue\":{\"id\":\"foo_id\"}}"] }
        end
      end

      expect(@service).to receive(:http_post)
        .with('http://redmine.acme.com/issues.json')
        .and_return(test.post('/issues.json'))

      expect { @service.receive_issue_impact_change(@config, @payload) }.to raise_error(/Redmine Issue Create Failed/)
    end
  end
end
