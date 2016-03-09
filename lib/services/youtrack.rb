class Service::YouTrack < Service::Base
  title 'YouTrack'

  string :base_url, :label => 'URL to YouTrack server:', :placeholder => 'https://myname.jetbrains.com/youtrack'
  string :project_id, :label => 'YouTrack Project ID:', :placeholder => 'PROJ'
  string :username, :label => 'Email address:', :placeholder => 'user@domain.com'
  password :password, :label => 'Password:'

  def receive_verification
    cookie_header = login_from_config(config)

    if project_exists?(config[:base_url], config[:project_id], cookie_header)
      log('verification successful')
    else
      display_error("Oops! We couldn't access YouTrack project: #{config[:project_id]}")
    end
  end

  def receive_issue_impact_change(payload)
    cookie_header = login_from_config(config)
    display_error("Invalid login for project_id: #{config[:project_id]}") unless cookie_header

    resp = http_method :put, "#{config[:base_url]}/rest/issue" do |req|
      req.headers['cookie'] = cookie_header
      req.params.update({
        :project => config[:project_id],
        :summary => "[Crashlytics] #{payload[:title]}",
        :description => issue_description_text(payload)
      })
    end

    if resp.status == 201
      log('issue_impact_change successful')
    else
      display_error("YouTrack issue creation failed - #{error_response_details(resp)}")
    end
  end

  private

  def project_exists?(youtrack_server_url, project_id, cookie_header)
    resp = http_get "#{youtrack_server_url}/rest/admin/project/#{project_id}" do |req|
      req.headers['cookie'] = cookie_header
    end
    resp.status == 200
  end

  def issue_description_text(payload)
    users_text = if payload[:impacted_devices_count] == 1
      'This issue is affecting at least 1 user who has crashed '
    else
      "This issue is affecting at least #{payload[:impacted_devices_count]} users who have crashed "
    end

    crashes_text = if payload[:crashes_count] == 1
      'at least 1 time.'
    else
      "at least #{payload[:crashes_count]} times."
    end

    issue_description = [
      'Crashlytics detected a new issue.',
      "#{payload[:title]} in #{payload[:method]}\n",
      "#{users_text} #{crashes_text}\n",
      "More information: #{payload[:url]}"
    ].join("\n")
  end

  def login_from_config(config)
    login(config[:base_url], config[:username], config[:password])
  end

  # Returns a string that can be used as a cookie header for authentication
  # with subsequent requests.  Logs exceptions and raises with a message on
  # any kind of error.
  def login(youtrack_base_url, username, password)
    begin
      resp = http_post "#{youtrack_base_url}/rest/user/login", :login => username, :password => password
    rescue => e
      log(e.message)
      display_error("YouTrack login had an unexpected error.")
    end

    if resp.status == 200
      resp.headers['set-cookie']
    else
      display_error("YouTrack login failed - #{error_response_details(resp)}")
    end
  end
end
