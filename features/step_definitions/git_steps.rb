require 'support/git_test_repository'
require 'time'

Given 'an application called "$name"' do |name|
  scenario_context.setup_application(name)
end

Given 'a commit "$version" by "$name" is created at "$time" for app "$app"' do |version, name, time, app|
  scenario_context.repository_for(app).create_commit(
    author_name: name,
    time: Time.zone.parse(time).utc,
    pretend_version: version,
  )
end

Given 'a commit "$version" with message "$message" is created at "$time"' do |version, message, time|
  scenario_context.last_repository.create_commit(
    author_name: 'Alice',
    message: message,
    time: Time.zone.parse(time).utc,
    pretend_version: version,
  )
end

Given 'the branch "$branch_name" is checked out' do |branch_name|
  scenario_context.last_repository.create_branch(branch_name)
  scenario_context.last_repository.checkout_branch(branch_name)
end

Given 'the branch "$branch" is merged with merge commit "$version" at "$time' do |branch, version, time|
  scenario_context.last_repository.merge_branch(
    branch_name: branch,
    pretend_version: version,
    author_name: 'Alice',
    time: Time.zone.parse(time).utc,
  )
end

Given 'all pull requests for "$commit" should be updated to "$status" status' do |_commit, status|
  expect(scenario_context.stubbed_requests[status]).to have_been_requested
end
