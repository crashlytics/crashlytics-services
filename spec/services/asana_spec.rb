require 'asana'
require 'spec_helper'

describe Service::Asana do

  it 'has a title' do
    expect(Service::Asana.title).to eq('Asana')
  end

  describe 'schema and display configuration' do
    subject { Service::Asana }

    it { is_expected.to include_page 'API Key', [:api_key] }
    it { is_expected.to include_string_field :api_key }

    it { is_expected.to include_page 'Project ID', [:project_id] }
    it { is_expected.to include_string_field :project_id }
  end

  context 'with service' do
    let(:service) { Service::Asana.new('event_name', {}) }
    let(:config) do
      {
        :api_key => 'key',
        :project_id => 'project_id_foo'
      }
    end
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
        response = service.receive_verification(config, nil)
        expect(response).to eq([true, 'Successfully verified Asana settings!'])
      end

      it 'should fail if API call raises an exception' do
        expect(service).to receive(:find_project).and_raise
        response = service.receive_verification(config, nil)
        expect(response.first).to eq(false)
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

        response = service.receive_issue_impact_change config, issue
        expect(response).to be true
      end

      it 'should raise if creating a new Asana task fails' do
        expect(service).to receive(:find_project).with(config[:api_key], project_id).and_return project
        expect(project).to receive(:workspace).and_return workspace
        expect(workspace).to receive(:create_task).with(expected_task_options).and_raise('fake')

        expect { service.receive_issue_impact_change config, issue }.to raise_error(RuntimeError, /fake/)
      end
    end
  end
end
