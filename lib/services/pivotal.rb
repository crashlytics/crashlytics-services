class Service::Pivotal < Service::Base
  string :project_url, :placeholder => "https://www.pivotaltracker.com/projects/yourproject/",
         :label => "URL to your Pivotal project:"
  password :api_key, :label => 'Paste your API Token (located under "Profile"). ' \
                             'Make sure API Access is on for your project in Project Settings!<br />' \
                             'Tip: Create a Crashlytics user for easier sorting.'

  # Create an issue on Pivotal
  def receive_issue_impact_change(payload)
    parsed = parse_url config[:project_url]
    url_prefix = parsed[:url_prefix]
    project_id = parsed[:project_id]
    http.ssl[:verify] = true

    users_text = if payload[:impacted_devices_count] == 1
      'This issue is affecting at least 1 user who has crashed '
    else
      "This issue is affecting at least #{ payload[:impacted_devices_count] } users who have crashed "
    end

    crashes_text = if payload[:crashes_count] == 1
      "at least 1 time.\n\n"
    else
      "at least #{ payload[:crashes_count] } times.\n\n"
    end

    issue_body = "Crashlytics detected a new issue.\n" + \
                 "*#{ payload[:title] }* in _#{ payload[:method] }_\n\n" + \
                 users_text + \
                 crashes_text + \
                 "More information: #{ payload[:url] }"
    post_body = {
      'name'     => payload[:title] + ' [Crashlytics]',
      'story_type'    => 'bug',
      'description' => issue_body }

    resp = http_post "https://#{url_prefix}/services/v5/projects/#{project_id}/stories" do |req|
      req.headers['Content-Type'] = 'application/json'
      req.headers['X-TrackerToken'] = config[:api_key]
      req.body = post_body.to_json
    end
    if resp.success?
      log('issue_impact_change successful')
    else
      display_error "Pivotal Issue Create Failed - #{error_response_details(resp)}"
    end
  end

  def receive_verification
    parsed = parse_url config[:project_url]
    url_prefix = parsed[:url_prefix]
    project_id = parsed[:project_id]
    http.ssl[:verify] = true

    resp = http_get "https://#{url_prefix}/services/v5/projects/#{project_id}/webhooks" do |req|
      req.headers['X-TrackerToken'] = config[:api_key]
    end
    if resp.status == 200
      log('verification successful')
    else
      display_error("Verification failure - #{error_response_details(resp)}")
    end
  end

  private
  require 'uri'
  def parse_url(url)
    uri = URI(url)
    {
      :url_prefix => uri.hostname,
      :project_id => uri.path.match(/\/projects\/(.+?)(\/|$)/)[1]
    }
  end
end
