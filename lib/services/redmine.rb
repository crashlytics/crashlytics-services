class Service::Redmine < Service::Base
  string :project_url, :placeholder => "http://redmine.acme.com/projects/yourproject",
         :label => "URL to your Redmine project:"
  string :api_key, :label => 'Paste your API Key (located under "My Account")<br><br>' \
                             'You must also "Enable REST web service" in ' \
                             'Admin > Settings > Auth.<br><br>' \
                             'Tip: Create a Crashlytics user for easier sorting.'

  page "Project", [ :project_url ]
  page "API Key", [ :api_key ]

  # Create an issue on Redmine
  def receive_issue_impact_change(config, payload)
    parsed = parse_url config[:project_url]
    project_id      = parsed[:project_id]
    http.basic_auth   parsed[:user], parsed[:password] if parsed[:user] || parsed[:password]

    users_text = ""
    crashes_text = ""
    if payload[:impacted_devices_count] == 1
      users_text = "This issue is affecting at least 1 user who has crashed "
    else
      users_text = "This issue is affecting at least #{ payload[:impacted_devices_count] } users who have crashed "
    end
    if payload[:crashes_count] == 1
      crashes_text = "at least 1 time.\n\n"
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
      raise "Redmine Issue Create Failed for issue url: #{payload[:url]}, status: #{resp.status }, body: #{resp.body}"
    end
    { :redmine_issue_id => JSON.parse(resp.body)['issue']['id'] }
  end

  def receive_verification(config, _)
    parsed = parse_url config[:project_url]
    http.basic_auth   parsed[:user], parsed[:password] if parsed[:user] || parsed[:password]

    path = parsed[:url_prefix] + "/issues.json"
    resp = http_get path, :key   => config[:api_key], :project_id => parsed[:project_id],
                          :limit => 1
    if resp.status == 200
      [true,  "Successfully verified Redmine settings"]
    else
      log "HTTP Error: status code: #{ resp.status }, body: #{ resp.body }"
      [false, "Oops! Please check your settings again."]
    end
  rescue => e
    log "Rescued a verification error in redmine: (url=#{config[:project_url]}) #{e}"
    [false, "Oops! Is your project url correct?"]
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
