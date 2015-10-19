require 'spec_helper'

describe Service::GitHub do
  let(:config) do
    {
      :access_token => 'foo_access_token',
      :repo => 'crashlytics/sample-project'
    }
  end

  it 'has a title' do
    expect(Service::GitHub.title).to eq('GitHub')
  end

  describe 'schema and display configuration' do
    subject { Service::GitHub }

    it { is_expected.to include_string_field :repo }
    it { is_expected.to include_string_field :access_token }

    it { is_expected.to include_page 'Repository', [:repo] }
    it { is_expected.to include_page 'Access token', [:access_token] }
  end

  describe '#receive_verification' do
    it 'returns true and a confirmation message on success' do
      service = Service::GitHub.new('verification', {})
      stub_request(:get, 'https://api.github.com/repos/crashlytics/sample-project').
         to_return(:status => 200, :body => '', :headers => {})

      success, message = service.receive_verification(config, nil)
      expect(success).to be true
      expect(message).to eq('Successfully accessed repo crashlytics/sample-project.')
    end

    it 'returns false and an error message on failure' do
      service = Service::GitHub.new('verification', {})
      stub_request(:get, 'https://api.github.com/repos/crashlytics/sample-project').
         to_return(:status => 404, :body => '', :headers => {})

      success, message = service.receive_verification(config, nil)
      expect(success).to be false
      expect(message).to eq('Could not access repository for crashlytics/sample-project.')
    end
  end

  describe '#receive_issue_impact_change' do
    let(:crashlytics_issue) do
      {
        :url => 'foo_issue_url',
        :app => { :name => 'foo_app_name' },
        :title => 'foo_issue_title',
        :method => 'foo_issue_method',
        :crashes_count => 'foo_issue_crashes_count',
        :impacted_devices_count => 'foo_issue_impacted_devices_count'
      }
    end
    let(:expected_issue_body) do
      "#### in foo_issue_method\n" \
      "\n" \
      "* Number of crashes: foo_issue_crashes_count\n" \
      "* Impacted devices: foo_issue_impacted_devices_count\n" \
      "\n" \
      "There's a lot more information about this crash on crashlytics.com:\n" \
      "[foo_issue_url](foo_issue_url)"
    end

    it 'create a new GitHub issue' do
      service = Service::GitHub.new('issue_impact_change', {})
      successful_response_json = '{"id":743,"number":42}'
      stub_request(:post, 'https://api.github.com/repos/crashlytics/sample-project/issues').
        to_return(
          :status => 201,
          :headers => { 'content-type' => 'application/json'},
          :body => successful_response_json)

      result = service.receive_issue_impact_change(config, crashlytics_issue)
      expect(result).to eq(:github_issue_number => 42)
    end

    it 'should raise if creating a new GitHub issue fails' do
      service = Service::GitHub.new('issue_impact_change', {})
      failed_response_json = '{"message":"GitHub error message"}'
      stub_request(:post, 'https://api.github.com/repos/crashlytics/sample-project/issues').
        to_return(
          :status => 401,
          :headers => { 'content-type' => 'application/json'},
          :body => failed_response_json)

      expect { service.receive_issue_impact_change config, crashlytics_issue }.
        to raise_error(Octokit::Unauthorized)
    end
  end
end
