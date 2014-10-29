require 'asana'
require 'spec_helper'

describe Service::FogBugz do
  it 'should have a title' do
    Service::FogBugz.title.should == 'FogBugz'
  end

  context 'with service' do
    let(:service) { Service::FogBugz.new('event_name', {}) }
    let(:config) do
      {
        :api_key => 'key',
        :project_url => 'https://yourproject.fogbugz.com'
      }
    end
    let(:payload) do
      {
        :title => 'foo title',
        :method => 'method name',
        :impact_level => 1,
        :impacted_devices_count => 1,
        :crashes_count => 1,
        :app => {
          :name => 'foo name',
          :bundle_identifier => 'foo.bar.baz'
        },
        :url => 'http://foo.com/bar'
      }
    end
    let(:error_response) { '<response><error code="0"></error></response>' }
    let(:invalid_response) { '' }

    describe :receive_verification do
      let(:success_response) { '<response><projects></projects></response>' }

      it 'succeeds given a valid response' do
        service.should_receive(:http_get).and_return(double(Faraday::Response, :body => success_response))
        response = service.receive_verification(config, nil)
        response.should == [true, 'Successfully verified Fogbugz settings']
      end

      it 'fails given an error response' do
        service.should_receive(:http_get).and_return(double(Faraday::Response, :body => error_response))
        response = service.receive_verification(config, nil)
        response.should == [false, 'Oops! Please check your API key again.']
      end

      it 'fails given an invalid response' do
        service.should_receive(:http_get).and_return(double(Faraday::Response, :body => invalid_response))
        response = service.receive_verification(config, nil)
        response.should == [false, 'Oops! Please check your API key again.']
      end
    end

    describe :receive_issue_impact_change do
      let(:case_id) { "1" }
      let(:success_response) { "<response><case ixBug='#{case_id}'></case></response>" }

      it 'creates a new case given a valid response' do
        service.should_receive(:http_post).and_return(double(Faraday::Response, :body => success_response))
        response = service.receive_issue_impact_change(config, payload)
        response.should == { :fogbugz_case_number => case_id }
      end

      it 'raises an exception given an error response' do
        service.should_receive(:http_post).and_return(double(Faraday::Response, :body => error_response))
        lambda { service.receive_issue_impact_change(config, payload) }.should raise_error
      end

      it 'raises an exception given an invalid response' do
        service.should_receive(:http_post).and_return(double(Faraday::Response, :body => invalid_response))
        lambda { service.receive_issue_impact_change(config, payload) }.should raise_error
      end
    end
  end
end
