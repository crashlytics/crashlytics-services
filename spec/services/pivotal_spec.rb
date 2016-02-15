require 'spec_helper'

describe Service::Pivotal do
  before do
    @service = Service::Pivotal.new(:project_url => 'https://www.pivotaltracker.com/s/projects/foo_project')
  end

  it 'has a title' do
    expect(Service::Pivotal.title).to eq('Pivotal')
  end

  describe 'schema and display configuration' do
    subject { Service::Pivotal }

    it { is_expected.to include_string_field :project_url }
    it { is_expected.to include_string_field :api_key }
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

      resp = @service.receive_verification
      expect(resp).to eq([true,  "Successfully verified Pivotal settings"])
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

      resp = @service.receive_verification
      expect(resp).to eq([false, "Oops! Please check your settings again."])
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

      resp = @service.receive_issue_impact_change(@payload)
      expect(resp).to eq(:pivotal_story_id => 'foo_id')
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

      expect { @service.receive_issue_impact_change(@payload) }.to raise_error(/Pivotal Issue Create/)
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
