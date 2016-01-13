Rails.application.config.event_types = [
  EventType.new(
    name: 'CircleCI (webhook)',
    endpoint: 'circleci',
    event_class: Events::CircleCiEvent),
  EventType.new(
    name: 'CircleCI',
    endpoint: 'circleci-manual',
    event_class: Events::CircleCiManualWebhookEvent),
  EventType.new(
    name: 'Deployment',
    endpoint: 'deploy',
    event_class: Events::DeployEvent),
  EventType.new(
    name: 'Jenkins',
    endpoint: 'jenkins',
    event_class: Events::JenkinsEvent),
  EventType.new(
    name: 'JIRA',
    endpoint: 'jira',
    event_class: Events::JiraEvent),
  EventType.new(
    name: 'UAT',
    endpoint: 'uat',
    event_class: Events::UatEvent),
  EventType.new(
    name: 'Manual test',
    endpoint: 'manual_test',
    event_class: Events::ManualTestEvent, internal: true),
]
