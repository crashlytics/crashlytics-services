require 'cgi'

class Service::GitLab < Service::Base
  title 'GitLab'

  string :url, :placeholder => 'https://gitlab.com', :label => 'Your GitLab URL:'
  string :project, :placeholder => 'Namespace/Project Name', :label => 'Your GitLab Namespace/Project:'
  password :private_token, :placeholder => 'GitLab Private Token', :label => 'Your GitLab Private Token:'

  def receive_verification
    http.ssl[:verify] = true
    resp = http_get(project_url(config[:project])) do |req|
      req.headers['PRIVATE-TOKEN'] = config[:private_token]
    end

    if resp.success?
      log('verification successful')
    else
      display_error("Could not access project #{config[:project]} - #{error_response_details(resp)}")
    end
  end

  def receive_issue_impact_change(issue)
    response = create_gitlab_issue(
      config[:project],
      config[:private_token],
      issue[:title],
      format_issue_impact_change_payload(issue)
    )

    if response.status != 201
      display_error "GitLab issue creation failed - #{error_response_details(response)}"
    end

    log('issue_impact_change successful')
  end

  private

  def format_issue_impact_change_payload(issue)
    "#### in #{issue[:method]}\n" \
    "\n" \
    "* Number of crashes: #{issue[:crashes_count]}\n" \
    "* Impacted devices: #{issue[:impacted_devices_count]}\n" \
    "\n" \
    "There's a lot more information about this crash on crashlytics.com:\n" \
    "[#{issue[:url]}](#{issue[:url]})"
  end

  def create_gitlab_issue(project, token, title, description)
    post_body = {
      'title' => title,
      'description' => description
    }

    http.ssl[:verify] = true
    http_post project_issues_url(project), project do |req|
      req.headers['PRIVATE-TOKEN'] = token
      req.headers['Content-Type'] = 'application/json'
      req.body                    = post_body.to_json
    end
  end

  def project_url(project)
    project ||= ''

    "#{config[:url]}/api/v3/projects/#{CGI.escape(project)}"
  end

  def project_issues_url(project)
    "#{project_url(project)}/issues"
  end
end
