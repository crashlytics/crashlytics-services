require 'spec_helper'

describe Service::Bitbucket do

  before do
    @config = {
      :username => 'user_name',
      :repo => 'project_name',
      :repo_owner => 'repo_owner'
    }
    @invalid_repo_owners = [nil, " \t\n",  ""]
  end

  it 'has a title' do
    expect(Service::Bitbucket.title).to eq('Bitbucket')
  end

  describe 'schema and display configuration' do
    subject { Service::Bitbucket }

    it { is_expected.to include_string_field :username }
    it { is_expected.to include_password_field :password }
    it { is_expected.to include_string_field :repo_owner }
    it { is_expected.to include_string_field :repo }

    it { is_expected.to include_page 'Username', [:username] }
    it { is_expected.to include_page 'Password', [:password] }
    it { is_expected.to include_page 'Repository Owner', [:repo_owner] }
    it { is_expected.to include_page 'Repository', [:repo] }
  end

  describe 'receive_verification' do
    before do
      @service = Service::Bitbucket.new('verification', {})
      @payload = {}
      @good_request_body = [200, {}, '']
      @good_response = [true, 'Successfully verified Bitbucket settings']
    end

    it 'should use the username field in the repo url when the repo owner is missing' do
      @invalid_repo_owners.each do |empty_value|
        test = Faraday.new do |builder|
          builder.adapter :test do |stub|
            stub.get('api/1.0/repositories/user_name/project_name/issues') { @good_request_body }
          end
        end

        expect(@service).to receive(:http_get)
          .with('https://bitbucket.org/api/1.0/repositories/user_name/project_name/issues')
          .and_return(test.get('/api/1.0/repositories/user_name/project_name/issues'))

        @config[:repo_owner] = empty_value

        resp = @service.receive_verification(@config, @payload)
        expect(resp).to eq(@good_response)
      end
    end

    it 'should succeed upon successful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.get('api/1.0/repositories/repo_owner/project_name/issues') { @good_request_body }
        end
      end

      expect(@service).to receive(:http_get)
        .with('https://bitbucket.org/api/1.0/repositories/repo_owner/project_name/issues')
        .and_return(test.get('/api/1.0/repositories/repo_owner/project_name/issues'))

      resp = @service.receive_verification(@config, @payload)
      expect(resp).to eq(@good_response)
    end

    it 'should fail upon unsuccessful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.get('/api/1.0/repositories/repo_owner/project_name/issues') { [500, {}, ''] }
        end
      end

      expect(@service).to receive(:http_get)
        .with('https://bitbucket.org/api/1.0/repositories/repo_owner/project_name/issues')
        .and_return(test.get('/api/1.0/repositories/repo_owner/project_name/issues'))

      resp = @service.receive_verification(@config, @payload)
      expect(resp).to eq([false, 'Oops! Please check your settings again.'])
    end
  end

  describe 'receive_issue_impact_change' do
    before do
      @service = Service::Bitbucket.new('issue_impact_change', {})
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
      @good_request_body = [200, {}, "{\"local_id\":12345}"]
      @good_response = { :bitbucket_issue_id => 12345 }
    end

    it 'should use the username field in the repo url when the repo owner is missing' do
      @invalid_repo_owners.each do |empty_value|
        test = Faraday.new do |builder|
          builder.adapter :test do |stub|
            stub.post('api/1.0/repositories/user_name/project_name/issues') { @good_request_body }
          end
        end

        expect(@service).to receive(:http_post)
          .with('https://bitbucket.org/api/1.0/repositories/user_name/project_name/issues')
          .and_return(test.post('/api/1.0/repositories/user_name/project_name/issues'))

        @config[:repo_owner] = empty_value

        resp = @service.receive_issue_impact_change(@config, @payload)
        expect(resp).to eq(@good_response)
      end
    end

    it 'should succeed upon successful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.post('/api/1.0/repositories/repo_owner/project_name/issues') { @good_request_body }
        end
      end

      expect(@service).to receive(:http_post)
        .with('https://bitbucket.org/api/1.0/repositories/repo_owner/project_name/issues')
        .and_return(test.post('/api/1.0/repositories/repo_owner/project_name/issues'))

      resp = @service.receive_issue_impact_change(@config, @payload)
      expect(resp).to eq(@good_response)
    end

    it 'should fail upon unsuccessful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.post('/api/1.0/repositories/repo_owner/project_name/issues') { [500, {}, "fakebody"] }
        end
      end

      expect(@service).to receive(:http_post)
        .with('https://bitbucket.org/api/1.0/repositories/repo_owner/project_name/issues')
        .and_return(test.post('/api/1.0/repositories/repo_owner/project_name/issues'))

      expect {
        @service.receive_issue_impact_change(@config, @payload)
      }.to raise_error('Bitbucket issue creation failed - HTTP status code: 500, body: fakebody')
    end
  end
end
