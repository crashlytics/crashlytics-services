require 'asana'
require 'uri'

class Service::Asana < Service::Base
  title 'Asana'
  
  string :api_key, :placeholder => 'Your Asana API key',
         :label => 'Your Asana API key can be found in Asana by ' \
         'clicking on your name in the lower lefthand pane, ' \
         'clicking \'Account Settings\' and selecting the \'APPS\' tab.'

  string :project_url, :placeholder => '',
         :label => 'The Asana project id for the project where you would like the ' \
         'Crashlytics tasks to be created.  You can find this using the Asana API or ' \
         'by visiting the project page in a browser and taking the first long number in the URL. ' \
         'For example, in the URL https://app.asana.com/0/3330339702444/7770339702888, the project_id ' \
         'is "3330339702444".'
         
  page 'Project ID', [:project_id]
  page 'API Key', [:api_key]
  
  def receive_verification(config, _)
    begin
      project = find_project config[:api_key], config[:project_id]
      [true,  "Successfully verified Asana settings!"]
    rescue => e
      log "Rescued a verification error in Asana: #{e}"
      [false, "Oops! Encountered an error. Please check your settings."]
    end
  end
  
  def receive_issue_impact_change(config, issue)
    task_options = {
      :name => issue[:title],
      :notes => create_notes(issue),
      :projects => [config[:project_id]]
    }

    project = find_project config[:api_key], config[:project_id]
    task = project.workspace.create_task task_options
    raise "Asana Task creation failed: #{task}" unless task.id
    { :asana_task_id => task.id }
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
  
  # Returns Asana::Project or raises if any error
  def find_project(api_key, project_id)
    Asana.configure {|client| client.api_key = api_key }
    Asana::Project.find project_id
  end
end