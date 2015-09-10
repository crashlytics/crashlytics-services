require 'spec_helper'
require 'webmock/rspec'

describe Service::YouTrack do

  it 'has a title' do
    expect(Service::YouTrack.title).to eq('YouTrack')
  end

  describe 'schema and display configuration' do
    subject { Service::YouTrack }

    it { is_expected.to include_string_field :base_url }
    it { is_expected.to include_string_field :project_id }
    it { is_expected.to include_string_field :username }

    it { is_expected.to include_page 'YouTrack Project', [:base_url, :project_id] }
    it { is_expected.to include_page 'Login Information', [:username, :password] }
  end

  def stub_successful_login_for(config)
    stub_request(:post, "#{config[:base_url]}/rest/user/login")
      .with(:body => { :login => config[:username], :password => config[:password]})
      .to_return(:status => 200, :body => {}.to_json, :headers => { 'Set-Cookie' => 'cookie-string' })
  end

  def stub_failed_login_for(config)
    stub_request(:post, "#{config[:base_url]}/rest/user/login")
      .with(:body => {:login => config[:username], :password => config[:password]})
      .to_return(:status => 500, :body => {}.to_json)
  end

  let(:service) { described_class.new('event_name', {}, {}) }
  let(:config) do
    {
        :base_url => 'http://example-project.youtrack.com',
        :project_id  => 'foo_project_id',
        :username => 'username',
        :password => 'password'
    }
  end

  def issue_payload(options = {})
    {
        :title                  => 'foo_title',
        :method                 => 'method name',
        :impact_level           => 1,
        :impacted_devices_count => 1,
        :crashes_count          => 1,
        :app                    => {
            :name              => 'foo name',
            :bundle_identifier => 'foo.bar.baz'
        },
        :url                    => 'http://foo.com/bar'
    }.merge(options)
  end

  describe '#login' do
    it 'should return cookie string on success' do
      stub_successful_login_for(config)
      resp = service.send :login, config[:base_url], config[:username], config[:password]
      expect(resp).to eq('cookie-string')
    end

    it 'should return false on failure' do
      stub_failed_login_for(config)
      resp = service.send :login, config[:base_url], config[:username], config[:password]
      expect(resp).to eq(false)
    end
  end


  describe '#receive_verification' do
    it 'should succeed if login is successful and project exists' do
      stub_successful_login_for(config)
      stub_request(:get, "#{config[:base_url]}/rest/admin/project/foo_project_id")
        .with({:headers => { 'Cookie' => 'cookie-string' }})
        .to_return(:status => 200, :body => {}.to_json)

      response = service.receive_verification(config, nil)
      expect(response).to eq([true, 'Successfully connected to your YouTrack project!'])
    end

    it 'should fail if login is successful but project does not exist' do
      stub_successful_login_for(config)
      stub_request(:get, "#{config[:base_url]}/rest/admin/project/foo_project_id")
        .with({:headers => { 'Cookie' => 'cookie-string' }})
        .to_return(:status => 500, :body => {}.to_json)

      response = service.receive_verification(config, nil)
      expect(response).to eq([false, 'Oops! Please check your YouTrack settings again.'])
    end

    it 'should fail on unhandled exception' do
      response = service.receive_verification({}, nil)
      expect(response).to eq([false, 'Oops! Please check your settings again.'])
    end
  end

  describe '#receive_issue_impact_change' do
    it 'should succeed if login is successful and PUT succeeds' do
      stub_successful_login_for(config)
      allow(service).to receive(:issue_description_text).with(issue_payload).and_return 'foo_issue_description'
      stub_request(:put, "#{config[:base_url]}/rest/issue")
        .with({
          :headers => { 'Cookie' => 'cookie-string' },
          :query => {
            :project => 'foo_project_id',
            :summary => '[Crashlytics] foo_title',
            :description => 'foo_issue_description'
          }
        }).to_return(:status => 201, :body => {}.to_json, :headers => { 'Location' => 'foo_youtrack_issue_url' })

      response = service.receive_issue_impact_change(config, issue_payload)
      expect(response).to eq(:youtrack_issue_url => 'foo_youtrack_issue_url')
    end

    it 'should fail if login is successful but PUT fails' do
      stub_successful_login_for(config)
      allow(service).to receive(:issue_description_text).with(issue_payload).and_return 'foo_issue_description'
      stub_request(:put, "#{config[:base_url]}/rest/issue")
        .with({
          :headers => { 'Cookie' => 'cookie-string' },
          :query => {
            :project => 'foo_project_id',
            :summary => '[Crashlytics] foo_title',
            :description => 'foo_issue_description'
          }
        }).to_return(:status => 500, :body => {}.to_json)

      expect { service.receive_issue_impact_change(config, issue_payload) }.to raise_exception(/issue creation failed/)
    end

    it 'should fail if login fails' do
      stub_failed_login_for(config)
      expect { service.receive_issue_impact_change(config, issue_payload) }.to raise_exception(/Invalid login/)
    end
  end

  describe '#issue_description_text' do
    it 'displays a singular message when only one device is impacted' do
      result = service.send(:issue_description_text,
          issue_payload(:impacted_devices_count => 1))

      expect(result).to match(/at least 1 user/)
    end

    it 'displays a pluralized message when multiple devices are impacted' do
      result = service.send(:issue_description_text,
          issue_payload(:impacted_devices_count => 2))

      expect(result).to match(/at least 2 users/)
    end

    it 'displays a singular message only one crash occurred' do
      result = service.send(:issue_description_text,
          issue_payload(:crashes_count => 1))

      expect(result).to match(/at least 1 time/)
    end

    it 'displays a pluralized message whem multiple crashes occurred' do
      result = service.send(:issue_description_text,
          issue_payload(:crashes_count => 2))

      expect(result).to match(/at least 2 times/)
    end

    it 'displays payload information' do
      result = service.send(:issue_description_text,
        issue_payload(:title => 'fake_title',
          :method => 'fake_method',
          :url => 'http://example.com/foobar'))

      expect(result).to match(/fake_title/)
      expect(result).to match(/fake_method/)
      expect(result).to match(/#{Regexp.escape('http://example.com/foobar')}/)
    end
  end
end
