require 'spec_helper'

describe Service::Pivotal, :type => :service do
  before do
    @logger = double('fake-logger', :log => nil)
    @config = { :project_url => 'https://www.pivotaltracker.com/s/projects/foo_project' }
    @service = Service::Pivotal.new(@config, lambda { |message| @logger.log(message) })
  end

  it 'has a title' do
    expect(Service::Pivotal.title).to eq('Pivotal')
  end

  describe 'schema and display configuration' do
    subject { Service::Pivotal }

    it { is_expected.to include_string_field :project_url }
    it { is_expected.to include_password_field :api_key }
  end

  describe 'receive_verification' do

    it 'should succeed upon successful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.get('/services/v3/projects/foo_project') { [200, {}, ''] }
        end
      end

      expect(@service).to receive(:http_get)
        .with('https://www.pivotaltracker.com/services/v3/projects/foo_project')
        .and_return(test.get('/services/v3/projects/foo_project'))

      @service.receive_verification
      expect(@logger).to have_received(:log).with('verification successful')
    end

    it 'should fail upon unsuccessful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.get('/services/v3/projects/foo_project') { [500, {}, ''] }
        end
      end

      expect(@service).to receive(:http_get)
        .with('https://www.pivotaltracker.com/services/v3/projects/foo_project')
        .and_return(test.get('/services/v3/projects/foo_project'))

      expect {
        @service.receive_verification
      }.to raise_error(Service::DisplayableError, 'Verification failure - HTTP status code: 500')
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
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          response = '<?xml version="1.0" encoding="UTF-8"?><story><id type="integer">foo_id</id></story>'
          stub.post('/services/v3/projects/foo_project/stories') { [201, {}, response] }
        end
      end

      expect(@service).to receive(:http_post)
        .with('https://www.pivotaltracker.com/services/v3/projects/foo_project/stories')
        .and_return(test.post('/services/v3/projects/foo_project/stories'))

      @service.receive_issue_impact_change(@payload)
      expect(@logger).to have_received(:log).with('issue_impact_change successful')
    end

    it 'should fail upon unsuccessful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.post('/services/v3/projects/foo_project/stories') { [500, {}, ''] }
        end
      end

      expect(@service).to receive(:http_post)
        .with('https://www.pivotaltracker.com/services/v3/projects/foo_project/stories')
        .and_return(test.post('/services/v3/projects/foo_project/stories'))

      expect {
        @service.receive_issue_impact_change(@payload)
      }.to raise_error(Service::DisplayableError, 'Pivotal Issue Create Failed - HTTP status code: 500')
    end
  end

  describe 'parse_url' do
    let(:service) { Service::Pivotal.new('issue_impact_change', {}) }

    it 'should parse_url with /s/ prefix correctly' do
      project_url = 'https://www.pivotaltracker.com/s/projects/12345'
      parsed_url = service.send :parse_url, project_url
      expect(parsed_url[:project_id]).to eq('12345')
    end

    it 'should parse_url without /s/ prefix correctly' do
      project_url = 'https://www.pivotaltracker.com/projects/12345'
      parsed_url = service.send :parse_url, project_url
      expect(parsed_url[:project_id]).to eq('12345')
    end
  end
end
