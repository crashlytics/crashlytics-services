require 'asana'
require 'uri'

class Service::Asana < Service::Base
  title 'Asana'
  logo 'v1/settings/app_settings/asana.png'
  
  string :api_key, :placeholder => 'Your Asana API key',
         :label => 'Your Asana API key can be found by \
         clicking on your name in the lefthand pane, \
         click \'Account Settings\' and select the \'APPS\' tab.'

  string :project_url, :placeholder => 'https://app.asana.com/0/:workspace/:project',
         :label => 'The URL to the project where you would like the \
         Crashlytics tasks to go.'
         
  page 'Project', [:project_url]
  page 'API Key', [:api_key]
  
  def receive_verification(config, _)
    url_parts = parse_url config[:project_url]
    workspace = find_workspace config[:api_key], url_parts[:workspace]
    if workspace.id == parsed_url[:workspace]
      [true,  "Successfully verified Asana settings!"]
    else
      log "Returned workspace.id (#{workspace.id}) did not match URL workspace (#{config[:project_url]})"
      [false, "Oops! Encountered an error. Please check your settings."]
    end
    rescue => e
      log "Rescued a verification error in Asana: #{e}"
      [false, "Oops! Encountered an error. Please check your settings."]
  end
  
  def receive_issue_impact_change(config, issue)
    url_parts = parse_url config[:project_url]
    task_options = {
      name: issue[:title],
      notes: create_notes(issue),
      projects: [url_parts[:project]]
    }

    workspace = find_workspace config[:api_key], url_parts[:workspace]
    response = workspace.create_task task_options
    unless response.id
      raise "Asana Task creation failed: #{(response.map {|e| e.join(' ') }).join(', ')}"
    end
    { :asana_task_id => response.id }
  end
  
  private
  def create_notes(issue)
    notes = ''
    notes << "#{issue[:url]}\n\n"
    notes << "Crashes in: #{issue[:method]}\n"
    notes << "Number of crashes: #{issue[:crashes_count]}\n"
    notes << "Impacted devices: #{issue[:impacted_devices_count]}"
    notes
  end
  
  # Returns Asana::Workspace or raises if any error
  def find_workspace(api_key, workspace_id)
    Asana.configure {|client| client.api_key = api_key }
    Asana::Workspace.find workspace_id
  end
  
  # Takes a URL string and returns a hash with :workspace and :project keys.
  # Raises on problem parsing URL
  def parse_url(url_string)
    url = URI.parse url_string
    path_parts = url.path.split '/'
    if url.scheme != 'https' or url.hostname != 'app.asana.com' or path_parts.length != 3
      raise "Please use a valid Asana URL in the format https://app.asana.com/0/:workspace/:project"
    end
    { workspace: path_parts[1], project: path_parts[2] }
  end
end