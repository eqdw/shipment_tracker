When 'I look up feature reviews for "$version" on "$app"' do |version, app|
  sha = scenario_context.resolve_version(version)
  feature_review_search_page.search_for(app: app, version: sha)
end

Then 'I should see the feature review known as "$known_as" for' do |known_as, links_table|
  links = links_table.hashes.map { |row|
    scenario_context.prepare_review(
      [{ app_name: row['app_name'], version: row['version'] }],
      row['uat'],
      known_as,
    )
    scenario_context.review_path(feature_review_nickname: known_as)
  }
  expect(feature_review_search_page.links).to match_array(links)
end

Then 'I select link to feature review "$link_number"' do |link_number|
  feature_review_search_page.click_nth_link(link_number)
end

Then 'I should see an alert: "$message"' do |message|
  expect(alert_message.text).to eq(message)
end
