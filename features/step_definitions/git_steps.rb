require 'support/git_repository_factory'

Given 'an application called "$name"' do |name|
  dir = Dir.mktmpdir
  @application = name
  @repo = Support::GitRepositoryFactory.new(dir)

  RepositoryLocation.create(uri: "file://#{dir}", name: name)
end

Given 'a commit "$version" by "$name" is created' do |version, name|
  @repo.create_commit(author_name: name, pretend_version: version)
end

Given 'a commit "$version" by "$author" is created for ticket "$jira_key"' do |version, author, jira_key|
  @repo.create_commit(
    author_name: author,
    pretend_version: version,
    message: "#{jira_key} work"
  )
end

Given 'a commit "$version" by "$name" is created with message "$message"' do |version, name, message|
  @repo.create_commit(
    author_name: name,
    pretend_version: version,
    message: message
  )
end
