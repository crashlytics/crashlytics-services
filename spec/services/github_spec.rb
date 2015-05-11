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

  describe :receive_verification do
    it :success do
      service = Service::GitHub.new('verification', {})
      expect(service).to receive(:github_repo).with('foo_access_token', 'crashlytics/sample-project')

      success, message = service.receive_verification(config, nil)
      expect(success).to be true
      expect(message).to eq('Successfully accessed repo crashlytics/sample-project.')
    end

    it :failure do
      service = Service::GitHub.new('verification', {})
      expect(service).to receive(:github_repo).with('foo_access_token', 'crashlytics/sample-project') { raise }

      success, message = service.receive_verification(config, nil)
      expect(success).to be false
      expect(message).to eq('Could not access repository for crashlytics/sample-project.')
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

    it 'should create a new GitHub issue' do
      service = Service::GitHub.new('issue_impact_change', {})
      github_issue = double(:id => 743, :number => 42)
      expect(service).to receive(:create_github_issue).with(
        'foo_access_token',
        'crashlytics/sample-project',
        'foo_issue_title',
        expected_issue_body
      ).and_return [github_issue, 201]

      expect(service.receive_issue_impact_change(config, crashlytics_issue)).to eq(:github_issue_number => 42)
    end

    it 'should raise if creating a new GitHub issue fails' do
      service = Service::GitHub.new('issue_impact_change', {})
      failed_github_issue = double(:message => 'GitHub error message')
      expect(service).to receive(:create_github_issue) { [failed_github_issue, 401] }
      expect { service.receive_issue_impact_change config, crashlytics_issue }.to raise_error 'GitHub issue creation failed: 401 - GitHub error message'
    end
  end
end
