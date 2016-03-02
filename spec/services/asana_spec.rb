require 'spec_helper'
require 'webmock/rspec'

describe Service::Asana, :type => :service do
  it 'has a title' do
    expect(Service::Asana.title).to eq('Asana')
  end

  describe 'schema and display configuration' do
    subject { Service::Asana }

    it { is_expected.to include_password_field :api_key }
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
      it 'should succeed if API can authenticate and find project' do
        stub_request(:get, "https://key:@app.asana.com/api/1.0/projects/project_id_foo").
          to_return(:status => 200, :body => '{}')

        service.receive_verification
        expect(logger).to have_received(:log).with('verification successful')
      end

      it 'should fail if API call raises an exception' do
        stub_request(:get, "https://key:@app.asana.com/api/1.0/projects/project_id_foo").
          to_return(:status => 403, :body => '')

        expect {
          service.receive_verification
        }.to raise_error(Service::DisplayableError, /Could not access project/)
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

      before do
        stub_request(:get, "https://key:@app.asana.com/api/1.0/projects/project_id_foo").
          and_return(:status => 200, :body => '{"data":{"workspace":{"id":1}}}')
      end

      it 'should create a new Asana task' do
        stub_request(:post, "https://key:@app.asana.com/api/1.0/tasks").
          and_return(:status => 200, :body => '')

        service.receive_issue_impact_change issue
        expect(logger).to have_received(:log).with('issue_impact_change successful')
      end

      it 'should raise if creating a new Asana task fails' do
        stub_request(:post, "https://key:@app.asana.com/api/1.0/tasks").
          and_return(:status => 403, :body => '')

        expect {
          service.receive_issue_impact_change issue
        }.to raise_error(Service::DisplayableError, /Asana task creation failed/)
      end
    end
  end
end
