require 'cgi'

class Service::GitLab < Service::Base
  title 'GitLab'

  string :url, :placeholder => 'https://gitlab.com', :label => 'Your GitLab URL:'
  string :project, :placeholder => 'Namespace/Project Name', :label => 'Your GitLab Namespace/Project:'
  string :private_token, :placeholder => 'GitLab Private Token', :label => 'Your GitLab Private Token:'

  page 'URL', [:url]
  page 'Project', [:project]
  page 'Private Token', [:private_token]

  def receive_verification(config, _)
    http.ssl[:verify] = true
    resp = http_get(project_url(config[:project])) do |req|
      req.headers['PRIVATE-TOKEN'] = config[:private_token]
    end

    if resp.success?
      [true, "Successfully accessed project #{config[:project]}."]
    else
      [false, "Could not access project #{config[:project]}."]
    end
  end

  def receive_issue_impact_change(config, issue)
    gitlab_issue, status_code = create_gitlab_issue(
      config[:project],
      config[:private_token],
      issue[:title],
      format_issue_impact_change_payload(issue)
    )

    raise "GitLab issue creation failed: #{status_code} - #{gitlab_issue['message']}" unless status_code == 201
    { :gitlab_issue_number => gitlab_issue['id'] }
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
    resp = http_post project_issues_url(project), project do |req|
      req.headers['PRIVATE-TOKEN'] = token
      req.headers['Content-Type'] = 'application/json'
      req.body                    = post_body.to_json
    end

    [JSON.parse(resp.body), resp.status]
  end

  def project_url(project)
    project ||= ''

    "#{config[:url]}/api/v3/projects/#{CGI.escape(project)}"
  end

  def project_issues_url(project)
    "#{project_url(project)}/issues"
  end
end
