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
      stub_request(:get, "http://redmine.acme.com/issues.json?key&limit=1&project_id=foo_project").
        to_return(:status => 200, :body => "", :headers => {})

      resp = @service.receive_verification(@config, @payload)
      expect(resp).to eq([true,  "Successfully verified Redmine settings"])
    end

    it 'should fail upon unsuccessful api response' do
      stub_request(:get, 'http://redmine.acme.com/issues.json?key&limit=1&project_id=foo_project').
        to_return(:status => 500, :body => 'body-text')

      success, msg = @service.receive_verification(@config, @payload)
      expect(success).to eq(false)
      expect(msg).to match(/Unexpected HTTP response from Redmine: 500/)
      expect(msg).not_to include('body-text')
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
      stub_body = { :issue => { :id => 'foo_id' }}
      stub_request(:post, "http://redmine.acme.com/issues.json?key").
        to_return(:status => 201, :body => stub_body.to_json)

      resp = @service.receive_issue_impact_change(@config, @payload)
      expect(resp).to eq(:redmine_issue_id => 'foo_id')
    end

    it 'should fail upon unsuccessful api response' do
      stub_request(:post, "http://redmine.acme.com/issues.json?key").
        to_return(:status => 500, :body => "", :headers => {})

      expect { @service.receive_issue_impact_change(@config, @payload) }.to raise_error(/Redmine Issue Create Failed for issue .* status: 500/)
    end
  end
end
