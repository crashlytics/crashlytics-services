require 'spec_helper'

describe Service::GitHub do
  let(:config) do
    {
      :access_token => 'foo_access_token',
      :repo => 'crashlytics/sample-project'
    }
  end

  it 'should have a title' do
    Service::GitHub.title.should == 'GitHub'
  end

  it 'should require two pages of information' do
    Service::GitHub.pages.should == [
      { :title => 'Repository', :attrs => [:repo] },
      { :title => 'Access token', :attrs => [:access_token] }
    ]
  end

  describe :receive_verification do
    it :success do
      service = Service::GitHub.new('verification', {})
      service.should_receive(:github_repo).with('foo_access_token', 'crashlytics/sample-project')

      success, message = service.receive_verification(config, nil)
      success.should be_true
      message.should == 'Successsfully accessed repo crashlytics/sample-project.'
    end

    it :failure do
      service = Service::GitHub.new('verification', {})
      service.should_receive(:github_repo).with('foo_access_token', 'crashlytics/sample-project') { raise }

      success, message = service.receive_verification(config, nil)
      success.should be_false
      message.should == 'Could not access repository for crashlytics/sample-project.'
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
      github_issue = mock(:id => 743, :number => 42)
      service.should_receive(:create_github_issue).with(
        'foo_access_token',
        'crashlytics/sample-project',
        'foo_issue_title',
        expected_issue_body
      ).and_return [github_issue, 201]

      service.receive_issue_impact_change(config, crashlytics_issue).should == { :github_issue_number => 42 }
    end

    it 'should raise if creating a new GitHub issue fails' do
      service = Service::GitHub.new('issue_impact_change', {})
      failed_github_issue = mock(:message => 'GitHub error message')
      service.should_receive(:create_github_issue) { [failed_github_issue, 401] }
      expect { service.receive_issue_impact_change config, crashlytics_issue }.to raise_error 'GitHub issue creation failed: 401 - GitHub error message'
    end
  end
end
