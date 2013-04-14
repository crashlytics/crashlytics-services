require 'asana'
require 'spec_helper'

describe Service::Asana do
  before do
    @config = {
      :api_key => 'key',
      :project_url => 'https://app.asana.com/0/workspace/project'
    }
    @parsed_url = { :workspace => 'workspace', :project => 'project' }
  end
  
  it 'should have a title' do
    Service::Asana.title.should == 'Asana'
  end

  it 'should have a logo' do
    Service::Asana.logo.should == 'v1/settings/app_settings/asana.png'
  end
  
  describe :receive_verification do
    before do
      @service = Service::Asana.new('verification', {})
    end
    
    it 'should respond' do
      @service.respond_to?(:receive_verification)
    end
    
    it 'should succeed upon successful api response' do
      @service.should_receive(:find_workspace).with(@config).and_return(mock(:id => @parsed_url[:workspace]))
      
      resp = @service.receive_verification(@config, @payload)
      resp.should == [true, 'Successfully verified Asana settings']
    end
    
    it 'should fail upon unsuccessful api response' do
      @service.should_receive(:find_workspace).with(@config).and_return(nil)
      
      resp = @service.receive_verification(@config, @payload)
      resp.should == [false, "Oops! Can not find #{@parsed_url[:workspace]} project. Please check your settings."]
    end
  end
  
  describe 'create_notes' do
    before do
      @service = Service::Asana.new('create_notes', {})
      @payload = {
        :title => 'foo title',
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
      
    it 'should respond' do
      @service.respond_to?(:create_notes)
    end
    
    it "should create well formatted notes for asana" do
      resp = @service.create_notes(@payload)
      resp.should == "#{@payload[:url]} \n\nCrashes in: #{@payload[:method]} \nNumber of crashes: #{@payload[:crashes_count]} \nImpacted devices: #{@payload[:impacted_devices_count]}"
    end
  end
  
  describe 'receive_issue_impact_change' do
    before do
      @service = Service::Asana.new('issue_impact_change', {})
      @payload = {
        :title => 'foo title',
        :impact_level => 1,
        :impacted_devices_count => 1,
        :crashes_count => 1,
        :app => {
          :name => 'foo name',
          :bundle_identifier => 'foo.bar.baz'
        },
        :url => "http://foo.com/bar"
      }
      @notes = @service.create_notes(@payload)
      @workspace = mock(:id => @parsed_url[:workspace])
    end
    
    it 'should respond' do
      @service.respond_to?(:issue_impact_change)
    end
    
    it 'should succeed upon successful api response' do
      @service.should_receive(:find_workspace).with(@config).and_return(@workspace)
      @workspace.should_receive(:create_task).and_return(mock(:id => '5007359597360'))
      resp = @service.receive_issue_impact_change(@config, @payload)
      resp.should == { :asana_task_id => '5007359597360' }
    end
    
    it 'should fail upon unsuccessful api response' do
      @service.should_receive(:find_workspace).and_return(nil)
      lambda { @service.receive_issue_impact_change(@config, @payload) }.should raise_error
    end
  end
end