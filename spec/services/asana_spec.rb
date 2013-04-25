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
        :project_id => 'project_id_foo'
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
      it 'should succeed if API can authenticate and find product' do
        @service.should_receive(:find_project).with(@config[:api_key], 'project_id_foo').and_return(mock(:id => 'project_id_foo'))
        response = @service.receive_verification(@config, nil)
        response.should == [true, 'Successfully verified Asana settings!']
      end
      
      it 'should fail if API call raises an exception' do
        @service.should_receive(:find_project).and_raise
        response = @service.receive_verification(@config, nil)
        response.first.should == false
      end
    end
  
    describe :receive_issue_impact_change do
      before do
        @notes = @service.send :create_notes, @issue
        @project_id = 'project_id_foo'
        @expected_task_options = {
          :name => 'foo title',
          :notes => @notes,
          :projects => [@project_id]
        }
        @project = mock(:id => @project_id)
        @workspace = mock(:id => 'workspace_id_foo')
        @task = mock(:id => 'new_task_id')
      end
      
      it 'should create a new Asana task' do
        @service.should_receive(:find_project).with(@config[:api_key], @project_id).and_return @project
        @project.should_receive(:workspace).and_return @workspace
        @workspace.should_receive(:create_task).with(@expected_task_options).and_return @task

        response = @service.receive_issue_impact_change @config, @issue
        response.should == { :asana_task_id => @task.id }
      end
      
      it 'should raise if creating a new Asana task fails' do
        @service.should_receive(:find_project).with(@config[:api_key], @project_id).and_return @project
        @project.should_receive(:workspace).and_return @workspace
        @workspace.should_receive(:create_task).with(@expected_task_options).and_raise
  
        expect { @service.receive_issue_impact_change @config, @issue }.to raise_error
      end
    end
  end
end