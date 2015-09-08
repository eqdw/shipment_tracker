Given 'a ticket "$key" with summary "$summary" is started' do |key, summary|
  scenario_context.create_and_start_ticket(
    key: key,
    summary: summary,
  )
end

Given 'adds the link for review "$nickname" to a comment for ticket "$jira_key"' do |nickname, jira_key|
  scenario_context.link_ticket_and_feature_review(jira_key, nickname)
end

Given 'ticket "$key" is approved by "$approver_email" at "$time"' do |jira_key, approver_email, time|
  scenario_context.approve_ticket(jira_key, approver_email: approver_email, time: time)
end

Given 'CircleCi "$outcome" for commit "$version"' do |outcome, version|
  payload = build(
    :circle_ci_manual_webhook_event,
    success?: outcome == 'passes',
    version: scenario_context.resolve_version(version),
  ).details

  post_event 'circleci-manual', payload
end

Given 'commit "$version" of "$app" is deployed by "$name" to server "$server"' do |version, app, name, server|
  payload = build(
    :deploy_event,
    server: server,
    app_name: app,
    version: scenario_context.resolve_version(version),
    deployed_by: name,
  ).details

  post_event 'deploy', payload
end

Given 'commit "$ver" of "$app" is deployed by "$name" to production at "$time"' do |ver, app, name, time|
  payload = build(
    :deploy_event,
    server: "#{app}.example.com",
    environment: 'production',
    app_name: app,
    version: scenario_context.resolve_version(ver),
    deployed_by: name,
  ).details

  travel_to Time.zone.parse(time) do
    post_event 'deploy', payload
  end
end

Given 'User Acceptance Tests at version "$sha" which "$outcome" on server "$server"' do |sha, outcome, server|
  payload = build(
    :uat_event,
    success: outcome == 'passed',
    test_suite_version: sha,
    server: server,
  ).details

  post_event 'uat', payload
end

def post_event(type, payload)
  OmniAuth.config.test_mode = true
  OmniAuth.config.mock_auth[:event_token] = OmniAuth::AuthHash.new(
    provider: 'event_token',
    uid:      type,
  )
  url = "/events/#{type}"
  post url, payload.to_json, 'CONTENT_TYPE' => 'application/json'

  Repositories::Updater.from_rails_config.run
end
