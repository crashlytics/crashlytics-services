class Service::Asana < Service::Base
  title 'Asana'

  password :api_key, :placeholder => 'Asana API key',
         :label => 'Your Asana API key can be found in Asana by ' \
         'clicking on your name in the lower lefthand pane, ' \
         'clicking \'Account Settings\' and selecting the \'APPS\' tab.'

  string :project_id, :placeholder => 'Asana project ID',
         :label => 'You can find this using the Asana API or ' \
         'by using the web UI.  In the Asana web UI, click on ' \
         'a project in the left pane, and then take the first long number in the URL.'

  def initialize(config, logger = Proc.new {})
    super
    configure_http
  end

  def receive_verification
    if find_project
      log('verification successful')
    else
      display_error("Could not access project #{config[:project_id]}.")
    end
  end

  def receive_issue_impact_change(issue)
    project = find_project

    display_error('Could not create Asana task: Project not found') unless project

    response = create_task(project, issue)

    if response.success?
      log('issue_impact_change successful')
    else
      display_error("Asana task creation failed: #{error_response_details(response)}")
    end
  end

  private

  def configure_http
    http.basic_auth(config[:api_key], nil)
  end

  def request_headers
    {
      'Accept' => 'application/json',
      'Content-type' => 'application/json'
    }
  end

  def find_project
    response = http_get(project_url) do |request|
      request.headers.merge!(request_headers)
    end

    if response.success?
      JSON.parse(response.body)
    end
  end

  def create_task(project, issue)
    workspace_id = project['data']['workspace']['id']

    response = http_post("#{asana_url}/tasks") do |request|
      request.headers.merge!(request_headers)
      request.body = {
        :data => {
          :workspace => workspace_id,
          :name => issue[:title],
          :notes => create_notes(issue),
          :assignee => 'me'
        }
      }.to_json
    end
  end

  def asana_url
    "https://app.asana.com/api/1.0"
  end

  def project_url
    "#{asana_url}/projects/#{config[:project_id]}"
  end

  def create_notes(issue)
    notes = ''
    notes << "#{issue[:url]}\n\n"
    notes << "Crashes in: #{issue[:method]}\n"
    notes << "Number of crashes: #{issue[:crashes_count]}\n"
    notes << "Impacted devices: #{issue[:impacted_devices_count]}"
    notes
  end
end
