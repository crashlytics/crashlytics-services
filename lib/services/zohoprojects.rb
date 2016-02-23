class Service::ZohoProjects < Service::Base
  title 'Zoho Projects'

  string :project_id,
    :label => "You need a Zoho Projects Premium or Enterprise plan along with the bug add-on to enable this integration. " \
    "To get your Project ID and Auth Token, head on over to your Zoho Projects Dashboard and look under \"Service Hooks\"" \
    "<br /><br />" \
    "Project ID"

  string :authtoken, :label => 'Auth Token'

  page 'Project Information', [:project_id, :authtoken]

  def receive_issue_impact_change(config, issue)
    payload = JSON.generate(:event => 'issue_impact_change', :payload => issue)

    response = send_request_to_projects config, payload
    if response.status != 200
      raise "Problem while sending request to Zoho Projects - #{error_response_details(response)}"
    end

    true
  end

  def receive_verification(config, _)
    payload = JSON.generate(:event => 'verification')

    response = send_request_to_projects config, payload
    if response.status == 400
      [false, 'Invalid Auth Token/Project ID']
    else
      [true, 'Verification successfully completed']
    end
  end

  private

  def service_hook_url
    'https://projectsapi.zoho.com/serviceHook'
  end

  def send_request_to_projects config, payload
    http.ssl[:verify] = true

    response = http_post(service_hook_url) do |req|
      req.params[:authtoken] = config[:authtoken]
      req.params[:pId] = config[:project_id]
      req.params[:pltype] = 'chook'
      req.params[:payload] = payload
    end

    return response
  end
end
