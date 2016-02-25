require 'asana'
require 'spec_helper'

describe Service::Asana do

  it 'has a title' do
    expect(Service::Asana.title).to eq('Asana')
  end

  describe 'schema and display configuration' do
    subject { Service::Asana }

    it { is_expected.to include_string_field :api_key }
    it { is_expected.to include_string_field :project_id }
  end

  context 'with service' do
    let(:logger) { double('fake-logger', :log => nil) }
    let(:config) do
      {
        :api_key => 'key',
        :project_id => 'project_id_foo'
      }
    end
    let(:service) { Service::Asana.new(config, lambda { |message| logger.log message }) }
    let(:issue) do
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

    describe :create_notes do
      it 'should create well formatted notes for asana' do
        notes = service.send :create_notes, issue
        expect(notes).to include issue[:url]
        expect(notes).to include issue[:method]
        expect(notes).to include issue[:crashes_count].to_s
        expect(notes).to include issue[:impacted_devices_count].to_s
        line_count = notes.split('/').length
        expect(line_count).to eq 4
      end
    end

    describe :receive_verification do
      it 'should succeed if API can authenticate and find product' do
        expect(service).to receive(:find_project).
          with(config[:api_key], 'project_id_foo').
          and_return(double(:id => 'project_id_foo'))
        service.receive_verification
        expect(logger).to have_received(:log).with('verification successful')
      end

      it 'should fail if API call raises an exception' do
        expect(service).to receive(:find_project).and_raise('fake-exception')
        expect {
          service.receive_verification
        }.to raise_error(Service::DisplayableError, 'Oops! Encountered an error. Please check your settings.')
        expect(logger).to have_received(:log).with('verification failed: fake-exception')
      end
    end

    describe :receive_issue_impact_change do
      let(:notes) { service.send :create_notes, issue }
      let(:project_id) { 'project_id_foo' }
      let(:expected_task_options) do
        {
          :name => 'foo title',
          :notes => notes,
          :projects => [project_id]
        }
      end
      let(:project) { double(:id => project_id) }
      let(:workspace) { double(:id => 'workspace_id_foo') }
      let(:task) { double(:id => 'new_task_id') }

      it 'should create a new Asana task' do
        expect(service).to receive(:find_project).with(config[:api_key], project_id).and_return project
        expect(project).to receive(:workspace).and_return workspace
        expect(workspace).to receive(:create_task).with(expected_task_options).and_return task

        service.receive_issue_impact_change issue
        expect(logger).to have_received(:log).with('issue_impact_change successful')
      end

      it 'should raise if creating a new Asana task fails' do
        expect(service).to receive(:find_project).with(config[:api_key], project_id).and_return project
        expect(project).to receive(:workspace).and_return workspace
        expect(workspace).to receive(:create_task).with(expected_task_options) { double(:id => nil) }

        expect {
          service.receive_issue_impact_change issue
        }.to raise_error(Service::DisplayableError, /Asana task creation failed/)
      end
    end
  end
end
