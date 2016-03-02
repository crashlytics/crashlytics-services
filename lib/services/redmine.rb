class Service::Redmine < Service::Base
  string :project_url, :placeholder => "http://redmine.acme.com/projects/yourproject",
         :label => "URL to your Redmine project:"
  password :api_key, :label => 'Paste your API Key (located under "My Account")<br><br>' \
                               'You must also "Enable REST web service" in ' \
                               'Admin > Settings > Auth.<br><br>' \
                               'Tip: Create a Crashlytics user for easier sorting.'

  # Create an issue on Redmine
  def receive_issue_impact_change(payload)
    parsed = parse_url config[:project_url]
    project_id      = parsed[:project_id]
    http.basic_auth   parsed[:user], parsed[:password] if parsed[:user] || parsed[:password]

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
                 "*#{ payload[:title] }* in @#{ payload[:method] }@\n\n" + \
                 users_text + \
                 crashes_text + \
                 "More information: #{ payload[:url] }"

    post_body = {
      :issue => {
        :subject     => payload[:title] + " [Crashlytics]",
        :project_id  => project_id,
        :description => issue_body } }

    path = parsed[:url_prefix] + "/issues.json"
    resp = http_post path do |req|
      req.headers['Content-Type'] = 'application/json'
      req.params['key']           = config[:api_key]
      req.body                    = post_body.to_json
    end
    unless resp.status == 201 # created
      display_error("Redmine Issue Create Failed - #{error_response_details(resp)}")
    end
    log('issue_impact_change successful')
  end

  def receive_verification
    parsed = parse_url config[:project_url]
    http.basic_auth   parsed[:user], parsed[:password] if parsed[:user] || parsed[:password]

    path = parsed[:url_prefix] + "/issues.json"
    resp = http_get path, :key   => config[:api_key], :project_id => parsed[:project_id],
                          :limit => 1
    if resp.status == 200
      log('verification successful')
    else
      display_error("Unexpected response from Redmine - #{error_response_details(resp)}")
    end
  end

  private
  require 'uri'
  def parse_url(url)
    uri = URI(url)
    { :url_prefix => url.match(/(.*?)\/projects\//)[1],
      :project_id => uri.path.match(/\/projects\/(.+?)(\/|$)/)[1],
      :user       => uri.user,
      :password   => uri.password }
  end
end
