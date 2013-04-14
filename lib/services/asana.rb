require 'asana'

class Service::Asana < Service::Base
  title 'Asana'
  logo 'v1/settings/app_settings/asana.png'
  
  string :api_key, :placeholder => 'Your Asana API key',
         :label => 'Your Asana API key can be found by \
         clicking on your name in the lefthand pane, \
         click \'Account Settings\' and select the \'APPS\' tab.'

  string :project_url, :placeholder => 'https://app.asana.com/0/<workspace>/<project>',
         :label => 'The URL to the project where you would like the \
         Crashlytics tasks to go.'
         
  page 'Project', [:project_url]
  page 'API Key', [:api_key]
  
  def receive_verification(config, _)
    parsed_url = parse_url(config[:project_url])
    workspace = find_workspace(config)
    if workspace.nil?
      [false, "Oops! Can not find #{parsed_url[:workspace]} project. Please check your settings."]
    elsif workspace.id == parsed_url[:workspace]
      [true,  "Successfully verified Asana settings"]
    end
    rescue => e
      log "Rescued a verification error in Asana: #{e}"
      [false, "Oops! Encountered an unexpected error (#{e}). Please check your settings."]
  end
  
  def receive_issue_impact_change(config, payload)
    workspace = find_workspace(config)
    parsed_url = parse_url(config[:project_url])
    notes = create_notes(payload)
    
    response = workspace.create_task(:name => payload[:title], :notes => notes, :projects => [parsed_url[:project]])
    unless response.id
      raise "Asana Task creation failed: #{(response.map {|e| e.join(' ') }).join(', ')}"
    end
    { :asana_task_id => response.id }
  end
  
  def create_notes(payload)
      "#{payload[:url]} \n\nCrashes in: #{payload[:method]} \nNumber of crashes: #{payload[:crashes_count]} \nImpacted devices: #{payload[:impacted_devices_count]}"
  end
  
  private
  def find_workspace(config)
    parsed_url = parse_url(config[:project_url])
    Asana.configure do |client|
      client.api_key = config[:api_key]
    end
    Asana::Workspace.find(parsed_url[:workspace])
  end
  
  def parse_url(url)
    url_parts = url.split('/') # => ["https:", "", "app.asana.com", "0", "<workspace>", "<project>"]
    { :workspace => url_parts[-2], :project => url_parts.last }
  end
end