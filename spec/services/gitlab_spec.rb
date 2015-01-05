require 'spec_helper'

describe Service::GitLab do
  let(:config) do
    {
      :project => 'root/example-project',
      :private_token => 'foo_access_token',
      :url => 'https://www.gitlabhq.com'
    }
  end

  it 'should have a title' do
    Service::GitLab.title.should == 'GitLab'
  end

  it 'should require three pages of information' do
    Service::GitLab.pages.should == [
      { :title => 'URL', :attrs => [:url] },
      { :title => 'Project', :attrs => [:project] },
      { :title => 'Private Token', :attrs => [:private_token] }
    ]
  end

  describe :receive_verification do
    it :success do
      service = Service::GitLab.new('verification', {})
      service.should_receive(:http_get).and_return(double(Faraday::Response, :success? => true))
      success, message = service.receive_verification(config, nil)
      success.should be true
      message.should == "Successfully accessed project #{config[:project]}."
    end

    it :failure do
      service = Service::GitLab.new('verification', {})
      service.should_receive(:http_get).and_return(double(Faraday::Response, :success? => false))

      success, message = service.receive_verification(config, nil)
      success.should be false
      message.should == "Could not access project #{config[:project]}."
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
      service.should_receive(:create_gitlab_issue).with(
        config[:project],
        config[:private_token],
        'foo_issue_title',
        expected_issue_body
      ).and_return [gitlab_issue, 201]

      service.receive_issue_impact_change(config, crashlytics_issue).should == { :gitlab_issue_number => 42 }
    end

    it 'should raise if creating a new GitLab issue fails' do
      service = Service::GitLab.new('issue_impact_change', {})
      failed_gitlab_issue = { 'message' => '"title" not given' }
      service.should_receive(:create_gitlab_issue) { [failed_gitlab_issue, 400] }
      expect { service.receive_issue_impact_change config, crashlytics_issue }.to raise_error 'GitLab issue creation failed: 400 - "title" not given'
    end
  end
end
