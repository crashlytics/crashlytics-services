require 'asana'

class Service::Asana < Service::Base
  title 'Asana'

  string :api_key, :placeholder => 'Asana API key',
         :label => 'Your Asana API key can be found in Asana by ' \
         'clicking on your name in the lower lefthand pane, ' \
         'clicking \'Account Settings\' and selecting the \'APPS\' tab.'

  string :project_id, :placeholder => 'Asana project ID',
         :label => 'You can find this using the Asana API or ' \
         'by using the web UI.  In the Asana web UI, click on ' \
         'a project in the left pane, and then take the first long number in the URL.'

  def receive_verification
    begin
      find_project config[:api_key], config[:project_id]
      log('verification successful')
    rescue => e
      log "verification failed: #{e}"
      display_error('Oops! Encountered an error. Please check your settings.')
    end
  end

  def receive_issue_impact_change(issue)
    task_options = {
      :name => issue[:title],
      :notes => create_notes(issue),
      :projects => [config[:project_id]]
    }

    project = find_project config[:api_key], config[:project_id]
    task = project.workspace.create_task task_options
    if task.id
      log('issue_impact_change successful')
    else
      display_error('Asana task creation failed')
    end
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
    Asana.configure { |client| client.api_key = api_key }
    Asana::Project.find project_id
  end
end
