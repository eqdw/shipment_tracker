When 'I view the releases for "$app"' do |app|
  releases_page.visit(app)
end

Then 'I should see the "$deploy_status" releases' do |deploy_status, releases_table|
  expected_releases = releases_table.hashes.map { |release_line|
    release = {
      'approved' => release_line.fetch('approved') == 'yes',
      'version' => scenario_context.resolve_version(release_line.fetch('version')).slice(0..6),
      'subject' => release_line.fetch('subject'),
      'feature_reviews' => release_line.fetch('review statuses'),
      'feature_review_paths' => nil,
      'committed_to_master_at' => nil,
    }

    nicknames = release_line.fetch('feature reviews').split(',').map(&:strip)
    release['feature_review_paths'] = nicknames.map { |nickname|
      scenario_context.review_path(feature_review_nickname: nickname)
    }

    master_commit_time = release_line.fetch('committed to master at')
    release['committed_to_master_at'] = Time.zone.parse(master_commit_time) if master_commit_time

    if deploy_status == 'deployed'
      time = release_line.fetch('last deployed at')
      if time.empty?
        release['time'] = nil
      else
        release['time'] = Time.zone.parse(time)
      end
    end

    release
  }

  actual_releases = releases_page.public_send("#{deploy_status}_releases".to_sym)
  expect(actual_releases).to match_array(expected_releases)
end
