class Service::YouTrack < Service::Base
  title 'YouTrack'

  string :base_url, :label => 'URL to YouTrack server:', :placeholder => 'https://myname.jetbrains.com/youtrack/'
  string :project_id, :label => 'YouTrack Project ID:', :placeholder => 'PROJ'
  string :username, :label => 'Email address:', :placeholder => 'user@domain.com'
  password :password, :label => 'Password:'

  page 'YouTrack Project', [:base_url, :project_id]
  page 'Login Information', [:username, :password]

  def receive_verification(config, _)
    cookie_header =  login_from_config(config)
    unless cookie_header
      log "YouTrack login returned failure"
      return [false, 'Oops! Please check your settings again.']
    end

    if project_exists?(config[:base_url], config[:project_id], cookie_header)
      [true, 'Successfully connected to your YouTrack project!']
    else
      log "Failed to access YouTrack project: #{config[:project_id]}"
      [false, 'Oops! Please check your YouTrack settings again.']
    end
  rescue => e
    log "Rescued a verification error in YouTrack integration: (base_url=#{config[:base_url]}, project=#{config[:project_id]}) #{e}"
    [false, 'Oops! Please check your settings again.']
  end

  def receive_issue_impact_change(config, payload)
    cookie_header = login_from_config(config)
    raise "Invalid login for project_id: #{config[:project_id]}" unless cookie_header

    resp = http_method :put, "#{config[:base_url]}/rest/issue" do |req|
      req.headers['cookie'] = cookie_header
      req.params.update({
        :project => config[:project_id],
        :summary => "[Crashlytics] #{payload[:title]}",
        :description => issue_description_text(payload)
      })
    end

    raise "YouTrack issue creation failed, status: #{ resp.status }, body: #{ resp.body }" unless resp.status == 201
    { :youtrack_issue_url => resp.headers['location'] }
  end

  private
  def project_exists?(youtrack_server_url, project_id, cookie_header)
    resp = http_get "#{youtrack_server_url}/rest/admin/project/#{project_id}" do |req|
      req.headers['cookie'] = cookie_header
    end
    log "YouTrack project_exists? url: #{youtrack_server_url}/rest/admin/project/#{project_id}, response: #{resp.status} #{resp.body}"
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
  # with subsequent requests.  Logs exceptions and returns false on any kind
  # of error.
  def login(youtrack_base_url, username, password)
    resp = http_post "#{youtrack_base_url}/rest/user/login", :login => username, :password => password
    if resp.status == 200
      resp.headers['set-cookie']
    else
      log "Failure response from YouTrack login: #{resp.status}, body: #{resp.body}"
      false
    end
  rescue => e
    log "YouTrack login failed for user: #{username}, baseurl: #{youtrack_base_url}, #{e}"
    false
  end
end
