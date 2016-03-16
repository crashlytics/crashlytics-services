require 'spec_helper'
require 'webmock/rspec'

describe Service::Jira, :type => :service do

  let(:logger) { double('fake-logger', :log => nil) }
  let(:logger_function) { lambda { |message| logger.log(message) }}
  let(:config) do
    {
      :project_url => 'https://example.com/browse/project_key',
      :username => "username",
      :password => "password",
    }
  end
  let(:service) do
    Service::Jira.new(config, logger_function)
  end

  it 'has a title' do
    expect(Service::Jira.title).to eq('Jira')
  end

  describe 'schema and display configuration' do
    subject { Service::Jira }

    it { is_expected.to include_string_field :project_url }
    it { is_expected.to include_string_field :username }
    it { is_expected.to include_password_field :password }
    it { is_expected.to include_string_field :issue_type }
  end

  describe '#receive_issue_impact_change' do

    def build_issue_impact_payload(overrides = {})
      {
        :title => 'foo title',
        :impact_level => 1,
        :impacted_devices_count => 1,
        :crashes_count => 1,
        :app => {
          :name => 'foo name',
          :bundle_identifier => 'foo.bar.baz'
        }
      }.merge(overrides)
    end

    before do
      allow(service).to receive(:create_jira_issue).with(anything, anything)
    end

    it 'customizes the issue description to account for singularization of the counts' do
      service.receive_issue_impact_change(build_issue_impact_payload(:impacted_devices_count => 1, :crashes_count => 1))

      expect(service).to have_received(:create_jira_issue).with(anything, /at least 1 user who has crashed at least 1 time./)
    end

    it 'customizes the issue description to account for pluralization of the counts' do
      service.receive_issue_impact_change(build_issue_impact_payload(:impacted_devices_count => 2, :crashes_count => 2))

      expect(service).to have_received(:create_jira_issue).with(anything, /at least 2 users who have crashed at least 2 times./)
    end

    it 'logs a message on success' do
      service.receive_issue_impact_change(build_issue_impact_payload)

      expect(logger).to have_received(:log).with('issue_impact_change successful')
    end

    it 'includes the issue description to account for singularization of the counts' do
      service.receive_issue_impact_change(build_issue_impact_payload(:impacted_devices_count => 1, :crashes_count => 1))

      expect(service).to have_received(:create_jira_issue).with(anything, /at least 1 user who has crashed at least 1 time./)
    end
  end

  describe '#receive_issue_velocity_alert' do

    def build_issue_velocity_alert(overrides = {})
      {
        :event => 'issue_velocity_alert',
        :display_id => '123',
        :method => 'method',
        :title => 'title',
        :crash_percentage => 1.03,
        :version => '1.0 (1.1)',
        :url => 'url',
        :app => {
          :name => 'AppName',
          :bundle_identifier => 'io.fabric.test',
          :platform => 'platform'
        }
      }.merge(overrides)
    end

    before do
      allow(service).to receive(:create_jira_issue).with(anything, anything)
    end

    it 'includes the dynamic and interesting velocity alerting info in the description of the issue it creates' do
      service.receive_issue_velocity_alert(
        build_issue_velocity_alert(:crash_percentage => 1.05, :version => '2.2.2 (2.x)', :app => { :name => 'AppName' }))

      expect(service).to have_received(:create_jira_issue).with(anything,
        /This issue crashed 1.05% of all AppName sessions in the past hour on version 2.2.2 \(2.x\)/
      )
    end
  end

  describe '#receive_verification' do
    it 'should succeed upon successful api response' do
      stub_request(:get, "https://username:password@example.com/rest/api/2/project/project_key").
         to_return(:status => 200, :body => '{"id":12345}')

      service.receive_verification
      expect(logger).to have_received(:log).with('verification successful')
    end

    it 'should fail upon unsuccessful api response' do
      stub_request(:get, "https://username:password@example.com/rest/api/2/project/project_key").
         to_return(:status => 500)

      expect {
        service.receive_verification
      }.to raise_error(Service::DisplayableError, /Jira Verification Failed/)
    end
  end

  describe 'http client' do
    it 'disables SSL checking when the project_url is http' do
      config[:project_url] = 'http://example.com/browse/project_key'
      expect(service.http.ssl.verify?).to be false
      expect(service.http.ssl.verify_mode).to eq(OpenSSL::SSL::VERIFY_NONE)
    end

    it 'enables SSL checking and peer verification when the project_url is https' do
      expect(service.http.ssl.verify?).to be true
      expect(service.http.ssl.verify_mode).to eq(OpenSSL::SSL::VERIFY_PEER)
    end
  end

  describe '#create_jira_issue' do
    it 'sends the summary and description as part of the post body' do
      stub_request(:get, "https://username:password@example.com/rest/api/2/project/project_key").
         to_return(:status => 200, :body => '{"id":12345}')

     stub_request(:post, "https://username:password@example.com/rest/api/2/issue").
        with(:body => /\"summary\":\"fake_summary\",\"description\":\"fake_description\"/).
        to_return(:status => 201, :body => '{"id":"foo"}')

      service.create_jira_issue('fake_summary', 'fake_description')
    end

    it 'sends issuetype name of Bug by default' do
      stub_request(:get, "https://username:password@example.com/rest/api/2/project/project_key").
         to_return(:status => 200, :body => '{"id":12345}')

      stub_request(:post, "https://username:password@example.com/rest/api/2/issue").
         with(:body => /\"issuetype\":{\"name\":\"Bug\"}}/).
         to_return(:status => 201, :body => '{"id":"foo"}')

      service.create_jira_issue('fake_summary', 'fake_description')
      expect(logger).to have_received(:log).with('create_jira_issue successful')
    end

    it 'sends custom issuetype name if provided' do
      service = Service::Jira.new(config.merge(:issue_type => 'Crash'), logger_function)

      stub_request(:get, "https://username:password@example.com/rest/api/2/project/project_key").
         to_return(:status => 200, :body => '{"id":12345}')

      stub_request(:post, "https://username:password@example.com/rest/api/2/issue").
         with(:body => /\"issuetype\":{\"name\":\"Crash\"}}/).
         to_return(:status => 201, :body => '{"id":"foo"}')

      service.create_jira_issue('fake_summary', 'fake_description')
      expect(logger).to have_received(:log).with('create_jira_issue successful')
    end

    it 'should succeed upon successful api response' do
      stub_request(:get, "https://username:password@example.com/rest/api/2/project/project_key").
         to_return(:status => 200, :body => '{"id":12345}')

      stub_request(:post, "https://username:password@example.com/rest/api/2/issue").
         to_return(:status => 201, :body => '{"id":"foo"}')

      service.create_jira_issue('fake_summary', 'fake_description')
      expect(logger).to have_received(:log).with('create_jira_issue successful')
    end

    it 'logs error details if they are provided in the response body' do
      stub_request(:get, "https://username:password@example.com/rest/api/2/project/project_key").
         to_return(:status => 200, :body => '{"id":12345}')

      stub_request(:post, "https://username:password@example.com/rest/api/2/issue").
         to_return(:status =>  400, :body => '{"errorMessages":[],"errors":{"fixVersions":"Fix Version/s is required."}}')

      expect {
        service.create_jira_issue('fake_summary', 'fake_description')
      }.to raise_error(Service::DisplayableError, /Jira Issue Create Failed/)
      expect(logger).to have_received(:log).with(/fixVersions/)
    end

    it 'should fail upon unsuccessful api response' do
      stub_request(:get, "https://username:password@example.com/rest/api/2/project/project_key").
         to_return(:status => 200, :body => '{"id":12345}')

      stub_request(:post, "https://username:password@example.com/rest/api/2/issue").
         to_return(:status => 500, :body => '{"id":"foo","key":"bar"}')

      expect {
        service.create_jira_issue('fake_summary', 'fake_description')
      }.to raise_error(Service::DisplayableError, /Jira Issue Create Failed/)
    end

    it 'should handle context path properly' do
      service = Service::Jira.new(
        config.merge(:project_url => 'https://mycompany.atlassian.net/jira/browse/PROJECT-KEY'), logger_function)

      stub_request(:get, "https://username:password@mycompany.atlassian.net/jira/rest/api/2/project/PROJECT-KEY").
         to_return(:status => 200, :body => '{"id":12345}')

      stub_request(:post, "https://username:password@mycompany.atlassian.net/jira/rest/api/2/issue").
         to_return(:status => 201, :body => '{"id":"foo"}')

      service.create_jira_issue('fake_summary', 'fake_description')
      expect(logger).to have_received(:log).with('create_jira_issue successful')
    end
  end

  describe '#parse_url' do
    it 'parses old versions of JIRA URLs' do
      parsed = service.parse_url('https://mycompany.atlassian.net/jira/browse/PROJECT-KEY')
      expect(parsed[:protocol]).to eq('https://')
      expect(parsed[:domain]).to eq('mycompany.atlassian.net')
      expect(parsed[:project_key]).to eq('PROJECT-KEY')
      expect(parsed[:context_path]).to eq('/jira')
    end

    it 'parses new versions of JIRA URLs' do
      parsed = service.parse_url('https://mycompany.atlassian.net/projects/PROJECT-KEY')
      expect(parsed[:protocol]).to eq('https://')
      expect(parsed[:domain]).to eq('mycompany.atlassian.net')
      expect(parsed[:project_key]).to eq('PROJECT-KEY')
      expect(parsed[:context_path]).to eq('')
    end

    it 'gracefully handles a bogus URL' do
      expect {
        service.parse_url('http://http://http://.com')
      }.to raise_error('Unexpected URL format')
    end
  end
end
