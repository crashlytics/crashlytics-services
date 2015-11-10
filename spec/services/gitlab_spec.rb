require 'spec_helper'

describe Service::GitLab do
  let(:config) do
    {
      :project => 'root/example-project',
      :private_token => 'foo_access_token',
      :url => 'https://www.gitlabhq.com'
    }
  end

  it 'has a title' do
    expect(Service::GitLab.title).to eq('GitLab')
  end

  describe 'schema and display configuration' do
    subject { Service::GitLab }

    it { is_expected.to include_string_field :url }
    it { is_expected.to include_string_field :project }
    it { is_expected.to include_string_field :private_token }

    it { is_expected.to include_page 'URL', [:url] }
    it { is_expected.to include_page 'Project', [:project] }
    it { is_expected.to include_page 'Private Token', [:private_token] }
  end

  describe :receive_verification do
    let(:service) { Service::GitLab.new('verification', config) }
    it 'reports success' do
      stub_request(:get, 'https://www.gitlabhq.com/api/v3/projects/root%2Fexample-project').
        with(:headers => { 'Private-Token' => 'foo_access_token' }).
        to_return(:status => 200, :body => '{"message":"Awesome"}')

      success, message = service.receive_verification(config, nil)
      expect(success).to be true
      expect(message).to eq("Successfully accessed project #{config[:project]}.")
    end

    it 'reports failure details on an unsuccessful attempt' do
      stub_request(:get, 'https://www.gitlabhq.com/api/v3/projects/root%2Fexample-project').
        with(:headers => { 'Private-Token' => 'foo_access_token' }).
        to_return(:status => 401, :body => '{"message":"401 Unauthorized"}')

      success, message = service.receive_verification(config, nil)
      expect(success).to be false
      expect(message).to eq("Could not access project #{config[:project]} - HTTP response code: 401")
    end
  end

  describe :receive_issue_impact_change do
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

    it 'should create a new GitLab issue' do
      service = Service::GitLab.new('issue_impact_change', {})
      gitlab_issue = { 'id' => 42 }
      expect(service).to receive(:create_gitlab_issue).with(
        config[:project],
        config[:private_token],
        'foo_issue_title',
        expected_issue_body
      ).and_return [gitlab_issue, 201]

      expect(service.receive_issue_impact_change(config, crashlytics_issue)).to eq(:gitlab_issue_number => 42)
    end

    it 'should raise if creating a new GitLab issue fails' do
      service = Service::GitLab.new('issue_impact_change', {})
      failed_gitlab_issue = { 'message' => '"title" not given' }
      expect(service).to receive(:create_gitlab_issue) { [failed_gitlab_issue, 400] }
      expect { service.receive_issue_impact_change config, crashlytics_issue }.to raise_error 'GitLab issue creation failed: 400 - "title" not given'
    end
  end
end
