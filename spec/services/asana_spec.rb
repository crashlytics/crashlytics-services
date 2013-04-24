require 'asana'
require 'spec_helper'

describe Service::Asana do
  it 'should have a title' do
    Service::Asana.title.should == 'Asana'
  end

  it 'should have a logo' do
    Service::Asana.logo.should == 'v1/settings/app_settings/asana.png'
  end

  context 'with service' do
    before do
      @service = Service::Asana.new('event_name', {})
      @config = {
        :api_key => 'key',
        :project_url => 'https://app.asana.com/0/ws/proj'
      }
      @issue = {
        :title => 'foo title',
        :method => 'method name',
        :impact_level => 1,
        :impacted_devices_count => 1,
        :crashes_count => 1,
        :app => {
          :name => 'foo name',
          :bundle_identifier => 'foo.bar.baz'
        },
        :url => "http://foo.com/bar"
      }
    end

    describe :parse_url do
      it 'should parse a valid url' do
        url_parts = @service.send :parse_url, 'https://app.asana.com/0/ws/proj'
        url_parts.should eq({ :workspace => 'ws', :project => 'proj' })
      end

      it 'should catch an invalid hostname' do
        expect { @service.send :parse_url, 'https://crashlytics.com/0/ws/proj' }.to raise_error
      end

      it 'should catch an invalid scheme' do
        expect { @service.send :parse_url, 'http://app.asana.com/0/ws/proj' }.to raise_error
      end

      it 'should catch an invalid path' do
        expect { @service.send :parse_url, 'https://app.asana.com/0/ws/proj/extra' }.to raise_error
        expect { @service.send :parse_url, 'https://app.asana.com/ws/proj' }.to raise_error
      end
    end

    describe :create_notes do
      it "should create well formatted notes for asana" do
        notes = @service.send :create_notes, @issue
        notes.should include @issue[:url]
        notes.should include @issue[:method]
        notes.should include @issue[:crashes_count].to_s
        notes.should include @issue[:impacted_devices_count].to_s
        line_count = notes.split('/').length
        line_count.should eq 4
      end
    end

    describe :receive_verification do
      it 'should succeed if API returns same workspace id' do
        @service.should_receive(:find_workspace).with(@config[:api_key], 'ws').and_return(mock(:id => 'ws'))
        response = @service.receive_verification(@config, @issue)
        response.should == [true, 'Successfully verified Asana settings!']
      end
      
      it 'should fail if API returns anything other than same workspace id' do
        @service.should_receive(:find_workspace).and_return(nil)
        response = @service.receive_verification(@config, @issue)
        response.first.should == false
      end

      it 'should fail if API call raises an exception' do
        @service.should_receive(:find_workspace).and_raise
        response = @service.receive_verification(@config, @payload)
        response.first.should == false
      end
    end
  
    describe :receive_issue_impact_change do
      before do
        @notes = @service.send :create_notes, @issue
        @workspace = mock(:id => 'ws')
        @expected_task_options = {
          :name => 'foo title',
          :notes => @notes,
          :projects => ['proj']
        }
      end
      
      it 'should create a new Asana task' do
        @service.should_receive(:find_workspace).with(@config[:api_key], 'ws').and_return @workspace
        @workspace.should_receive(:create_task).with(@expected_task_options).and_return(mock(:id => 'new_task_id'))

        response = @service.receive_issue_impact_change @config, @issue
        response.should == { :asana_task_id => 'new_task_id' }
      end
      
      it 'should raise if creating a new Asana task fails' do
        @service.should_receive(:find_workspace).with(@config[:api_key], 'ws').and_return @workspace
        @workspace.should_receive(:create_task).with(@expected_task_options).and_return nil

        expect { @service.receive_issue_impact_change @config, @issue }.to raise_error
      end
    end
  end
end