require 'spec_helper'
require 'webmock/rspec'
require 'base64'

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
  let(:headers) {
    username_password = config[:username] + ":" + config[:password]
    { 'Authorization' => "Basic #{Base64.strict_encode64(username_password)}" }
  }

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

  describe 'receive_verification' do
    it 'should succeed upon successful api response' do
      stub_request(:get, "https://example.com/rest/api/2/project/project_key").
         with(:headers => headers).
         to_return(:status => 200, :body => '{"id":12345}')

      service.receive_verification
      expect(logger).to have_received(:log).with('verification successful')
    end

    it 'should fail upon unsuccessful api response' do
      stub_request(:get, "https://example.com/rest/api/2/project/project_key").
         with(:headers => headers).
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

  describe 'receive_issue_impact_change' do
    let(:payload) do
      {
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

    it 'sends issuetype name of Bug by default' do
      stub_request(:get, "https://example.com/rest/api/2/project/project_key").
         with(:headers => headers).
         to_return(:status => 200, :body => '{"id":12345}')

      stub_request(:post, "https://example.com/rest/api/2/issue").
         with(:body => /\"issuetype\":{\"name\":\"Bug\"}}/, :headers => headers).
         to_return(:status => 201, :body => '{"id":"foo"}')

      service.receive_issue_impact_change(payload)
      expect(logger).to have_received(:log).with('issue_impact_change successful')
    end

    it 'sends custom issuetype name if provided' do
      service = Service::Jira.new({
        :project_url => 'https://example.com/browse/project_key',
        :issue_type => 'Crash'}, logger_function)

      stub_request(:get, "https://example.com/rest/api/2/project/project_key").
         to_return(:status => 200, :body => '{"id":12345}')

      stub_request(:post, "https://example.com/rest/api/2/issue").
         with(:body => /\"issuetype\":{\"name\":\"Crash\"}}/).
         to_return(:status => 201, :body => '{"id":"foo"}')

      service.receive_issue_impact_change(payload)
      expect(logger).to have_received(:log).with('issue_impact_change successful')
    end

    it 'should succeed upon successful api response' do
      stub_request(:get, "https://example.com/rest/api/2/project/project_key").
         with(:headers => headers).
         to_return(:status => 200, :body => '{"id":12345}')

      stub_request(:post, "https://example.com/rest/api/2/issue").
         with(:headers => headers).
         to_return(:status => 201, :body => '{"id":"foo"}')

      service.receive_issue_impact_change(payload)
      expect(logger).to have_received(:log).with('issue_impact_change successful')
    end

    it 'logs error details if they are provided in the response body' do
      stub_request(:get, "https://example.com/rest/api/2/project/project_key").
         with(:headers => headers).
         to_return(:status => 200, :body => '{"id":12345}')

      stub_request(:post, "https://example.com/rest/api/2/issue").
         with(:headers => headers).
         to_return(:status =>  400, :body => '{"errors":{"key":"error_details"}}')

      expect {
        service.receive_issue_impact_change(payload)
      }.to raise_error(Service::DisplayableError, /Jira Issue Create Failed/)
      expect(logger).to have_received(:log).with(/error_details/)
    end

    it 'should fail upon unsuccessful api response' do
      stub_request(:get, "https://example.com/rest/api/2/project/project_key").
         with(:headers => headers).
         to_return(:status => 200, :body => '{"id":12345}')

      stub_request(:post, "https://example.com/rest/api/2/issue").
         with(:headers => headers).
         to_return(:status => 500, :body => '{"id":"foo","key":"bar"}')

      expect {
        service.receive_issue_impact_change(payload)
      }.to raise_error(Service::DisplayableError, /Jira Issue Create Failed/)
    end

    it 'should handle context path properly' do
      config[:project_url] = 'https://mycompany.atlassian.net/jira/browse/PROJECT-KEY'
      stub_request(:get, "https://mycompany.atlassian.net/jira/rest/api/2/project/PROJECT-KEY").
         with(:headers => headers).
         to_return(:status => 200, :body => '{"id":12345}')

      stub_request(:post, "https://mycompany.atlassian.net/jira/rest/api/2/issue").
         with(:headers => headers).
         to_return(:status => 201, :body => '{"id":"foo"}')

      service.receive_issue_impact_change(payload)
      expect(logger).to have_received(:log).with('issue_impact_change successful')
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
