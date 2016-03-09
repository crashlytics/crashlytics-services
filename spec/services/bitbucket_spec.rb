require 'spec_helper'

describe Service::Bitbucket, :type => :service do
  let(:config) do
    {
      :username => 'user_name',
      :repo => 'project_name',
      :repo_owner => 'repo_owner'
    }
  end

  let(:invalid_repo_owners) { [nil, " \t\n",  ""] }
  let(:logger) { double('fake-logger', :log => nil) }
  let(:service) { Service::Bitbucket.new(config, lambda { |message| logger.log message }) }

  it 'has a title' do
    expect(Service::Bitbucket.title).to eq('Bitbucket')
  end

  describe 'schema and display configuration' do
    subject { Service::Bitbucket }

    it { is_expected.to include_string_field :username }
    it { is_expected.to include_password_field :password }
    it { is_expected.to include_string_field :repo_owner }
    it { is_expected.to include_string_field :repo }
  end

  describe 'receive_verification' do
    let(:good_request_body) { [200, {}, ''] }

    it 'should use the username field in the repo url when the repo owner is missing' do
      invalid_repo_owners.each do |empty_value|
        test = Faraday.new do |builder|
          builder.adapter :test do |stub|
            stub.get('api/1.0/repositories/user_name/project_name/issues') { good_request_body }
          end
        end

        expect(service).to receive(:http_get)
          .with('https://bitbucket.org/api/1.0/repositories/user_name/project_name/issues')
          .and_return(test.get('/api/1.0/repositories/user_name/project_name/issues'))

        config[:repo_owner] = empty_value

        service.receive_verification
      end

      expect(logger).to have_received(:log).with('verification successful').exactly(3).times
    end

    it 'should succeed upon successful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.get('api/1.0/repositories/repo_owner/project_name/issues') { good_request_body }
        end
      end

      expect(service).to receive(:http_get)
        .with('https://bitbucket.org/api/1.0/repositories/repo_owner/project_name/issues')
        .and_return(test.get('/api/1.0/repositories/repo_owner/project_name/issues'))

      service.receive_verification
      expect(logger).to have_received(:log).with('verification successful')
    end

    it 'should fail upon unsuccessful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.get('/api/1.0/repositories/repo_owner/project_name/issues') { [500, {}, ''] }
        end
      end

      expect(service).to receive(:http_get)
        .with('https://bitbucket.org/api/1.0/repositories/repo_owner/project_name/issues')
        .and_return(test.get('/api/1.0/repositories/repo_owner/project_name/issues'))

      expect {
        service.receive_verification
      }.to raise_error(Service::DisplayableError, 'Oops! Is your repository url correct?')
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
    let(:good_request_body) { [200, {}, "{\"local_id\":12345}"] }

    it 'should use the username field in the repo url when the repo owner is missing' do
      invalid_repo_owners.each do |empty_value|
        test = Faraday.new do |builder|
          builder.adapter :test do |stub|
            stub.post('api/1.0/repositories/user_name/project_name/issues') { good_request_body }
          end
        end

        expect(service).to receive(:http_post)
          .with('https://bitbucket.org/api/1.0/repositories/user_name/project_name/issues')
          .and_return(test.post('/api/1.0/repositories/user_name/project_name/issues'))

        config[:repo_owner] = empty_value

        service.receive_issue_impact_change(payload)
      end

      expect(logger).to have_received(:log).with('issue_impact_change successful').exactly(3).times
    end

    it 'should succeed upon successful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.post('/api/1.0/repositories/repo_owner/project_name/issues') { good_request_body }
        end
      end

      expect(service).to receive(:http_post)
        .with('https://bitbucket.org/api/1.0/repositories/repo_owner/project_name/issues')
        .and_return(test.post('/api/1.0/repositories/repo_owner/project_name/issues'))

      service.receive_issue_impact_change(payload)
      expect(logger).to have_received(:log).with('issue_impact_change successful')
    end

    it 'should fail upon unsuccessful api response' do
      test = Faraday.new do |builder|
        builder.adapter :test do |stub|
          stub.post('/api/1.0/repositories/repo_owner/project_name/issues') { [500, {}, "fakebody"] }
        end
      end

      expect(service).to receive(:http_post)
        .with('https://bitbucket.org/api/1.0/repositories/repo_owner/project_name/issues')
        .and_return(test.post('/api/1.0/repositories/repo_owner/project_name/issues'))

      expect {
        service.receive_issue_impact_change(payload)
      }.to raise_error(Service::DisplayableError, 'Bitbucket issue creation failed - HTTP status code: 500')
    end
  end
end
