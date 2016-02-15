=======
4.0.0
------
- Simplify signatures that need to be implemented by service subclasses.
- Remove 'pages' annotation, which is no longer in use.

3.32.0
------
- Further reduce use of response body in error messages
- Stop attempting to parse response.body to produce unique identifiers for third-party hook items
- Stop using :no_resource as an indicator of success and prefer true

3.31.1
------
- Fix a broken test. Check URI schemes more pedantically.

3.31.0
------
- Prevent requests from going to internal or restricted IP addresses. Should reduce the error rate.

3.30.0
------
- Demystify errors coming from YouTrack.

3.29.0
------
- Use Jira issueType name instead of ID, and allow it to be overridden.

3.28.0
------
- Generally reduce our use of response.body in describing errors.

3.25.0
------
- Simplify Redmine error reporting to demystify the test payload content that was confusing the UI.

3.24.0
------
- Simplify Redmine error reporting to ensure proper display when resurfacing in the UI.

3.23.0
------
- Improve GitLab verification error message to display HTTP response code.

3.22.0
------
- Simplify WebHook error reporting to ensure proper display when resurfacing in the UI.

3.21.0
------
- Remove unused Jira sync_issues logic, to be reimplemented in the future.
- Simplify Jira error reporting to ensure proper display when resurfacing in the UI.

3.20.0
-----
- Update Github to support enterprise customers by allowing the api_endpoint field to be provided.

3.19.1
-----
- Update development version of RSpec to 3.3 and fix deprecated specs.
- Add this CHANGELOG.md file.
