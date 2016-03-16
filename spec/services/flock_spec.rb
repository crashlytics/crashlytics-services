require 'spec_helper'
require 'webmock/rspec'

describe Service::Flock do
  let(:config) do
    {
      :url => 'https://api.flock.co/hooks/sendMessage/3216b6b0-79bc-419d-9d95-46a49d164936'
    }
  end
  let(:logger) { double('fake-logger', :log => nil) }
  let(:service) { Service::Flock.new(config, lambda { |message| logger.log(message) }) }

  it 'has a title' do
    expect(Service::Flock.title).to eq('Flock')
  end

  describe 'schema and display configuration' do
    subject { Service::Flock }

    it { is_expected.to include_string_field :url }
  end

  def stub_http_post_request(expected_body)
    stub_request(:post, 'https://api.flock.co/hooks/sendMessage/3216b6b0-79bc-419d-9d95-46a49d164936')
      .with(:body => expected_body, :headers => { 'Content-Type' => 'application/json' })
  end

  describe '#receive_verification' do
    let(:expected_body) do
     {
       :text => 'Successfully configured Flock service hook with Crashlytics'
     }
    end

    it 'a 200 response as a success' do
      stub_http_post_request(expected_body).to_return(:status => 200)
      service.receive_verification
      expect(logger).to have_received(:log).with('verification successful')
    end

    it 'escalates a non-200 response as a failure' do
      stub_http_post_request(expected_body).to_return(:status => 400)

      expect {
        service.receive_verification
      }.to raise_error(Service::DisplayableError, 'Flock verification failed - HTTP status code: 400')
    end
  end

  describe '#extract_flock_message' do
    let(:payload) do
      {
        :title => 'foo title',
        :method => 'foo method',
        :impacted_devices_count => 1,
        :crashes_count => 1,
        :app => {
          :name => 'foo name'
        },
        :url => 'foo url'
      }
    end
    it 'displays a readable message from payload' do
      message = service.extract_flock_message(payload)
      expect(message).to eq("foo name crashed at foo title\n"+
      "Method: foo method\n" +
      "Number of crashes: 1\n" +
      "Number of impacted devices: 1\n" +
      "More information: foo url")
    end
  end

  describe '#receive_issue_impact_change' do
    let(:payload) do
      {
        :title => 'foo title',
        :method => 'foo method',
        :impacted_devices_count => 1,
        :crashes_count => 1,
        :app => {
          :name => 'foo name'
        },
        :url => 'foo url'
      }
    end


    let(:expected_body) do
      {
        :text => service.extract_flock_message(payload)
      }
    end

    it 'a 200 reponse as success to post a message to Flock for issue impact change' do
      stub_http_post_request(expected_body).to_return(:status => 200)
      service.receive_issue_impact_change(payload)
      expect(logger).to have_received(:log).with('issue_impact_change successful')
    end

    it 'escalates a non-200 response as failure to post a message to Flock for issue impact change' do
      stub_http_post_request(expected_body).to_return(:status => 400)
      expect {
        service.receive_issue_impact_change(payload)
      }.to raise_error(Service::DisplayableError, 'Flock issue impact change failed - HTTP status code: 400')
    end
  end
end
