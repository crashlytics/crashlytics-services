class Service::ZohoProjects < Service::Base
  title 'Zoho Projects'

  string :project_id,
    :label => "You need a Zoho Projects Premium or Enterprise plan along with the bug add-on to enable this integration. " \
    "To get your Project ID and Auth Token, head on over to your Zoho Projects Dashboard and look under \"Service Hooks\"" \
    "<br /><br />" \
    "Project ID"

  password :authtoken, :label => 'Auth Token'

  def receive_issue_impact_change(issue)
    payload = JSON.generate(:event => 'issue_impact_change', :payload => issue)

    response = send_request_to_projects config, payload
    if response.status != 200
      display_error("Problem while sending request to Zoho Projects - #{error_response_details(response)}")
    end

    log('issue_impact_change successful')
  end

  def receive_verification
    payload = JSON.generate(:event => 'verification')

    response = send_request_to_projects config, payload
    if response.status == 400
      display_error('Invalid Auth Token/Project ID')
    elsif response.success?
      log('verification successful')
    else
      display_error("ZohoProjects verification failed - #{error_response_details(response)}")
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
