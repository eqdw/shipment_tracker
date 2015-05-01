When 'I compare the beginning with the last commit for "$name"' do |name|
  feature_audit_page.request(
    project_name: name,
    from: nil,
    to: @repo.commits.last.version
  )
end

When 'I compare the first commit with the fourth commit for "$name"' do |name|
  feature_audit_page.request(
    project_name: name,
    from: @repo.commits.fetch(0).version,
    to: @repo.commits.fetch(3).version
  )
end

When 'I compare the second commit with the fourth commit for "$name"' do |name|
  feature_audit_page.request(
    project_name: name,
    from: @repo.commits.fetch(1).version,
    to: @repo.commits.fetch(3).version
  )
end

When 'I compare the commit "$commit" with the second commit for "$name"' do |commit, name|
  feature_audit_page.request(
    project_name: name,
    from: commit,
    to: @repo.commits.fetch(1).version
  )
end

Then 'I should only see the authors $authors' do |authors|
  expect(error_message).to_not be_present, "Did not expect any errors, but got: #{error_message.text}"
  expect(feature_audit_page.authors).to match_array(authors.gsub(' and ', ', ').split(', '))
end

When 'I review the deploys for "$app_name"' do |app_name|
  feature_audit_page.request(project_name: app_name)
end

Then 'I should only see the deploys' do |table|
  expected_deploys = table.hashes.map {|deploy|
    Sections::DeploySection.new(
      server: deploy.fetch("server"),
      deployed_at: deploy.fetch("deployed_at"),
      deployed_by: deploy.fetch("deployed_by"),
      version: @repo.commit_for_pretend_version(deploy.fetch("commit"))
    )
  }

  expect(feature_audit_page.deploys).to match_array(expected_deploys)
end