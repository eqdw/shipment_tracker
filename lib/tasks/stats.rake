namespace :stats do
  desc 'Counts releases'
  task :approved_releases, [:from_date, :to_date, :per_page] => :environment do |_, args|
    args.with_defaults(date_from: nil, date_to: nil, per_page: 50)
    from_date = args.from_date ? Time.parse(args.from_date) : Time.current.beginning_of_day - 7.days
    to_date = args.to_date ? Time.parse(args.to_date) : from_date - 7.days
    per_page = args.per_page.to_i

    puts "STATS INFO: Evaluating releases from #{from_date.strftime('%F')} until #{to_date.strftime('%F')}"
    puts "STATS INFO: Incursion-depth: last #{per_page} commits"

    no_approval_count_all_apps = 0
    approval_pending_count_all_apps = 0
    total_count_all_apps = 0

    GitRepositoryLocation.app_names.each do |app_name|
      puts "STATS INFO: Evaluating app: #{app_name}"
      git_repo = GitRepositoryLoader.from_rails_config.load(app_name)

      releases = Queries::ReleasesQuery
                 .new(per_page: per_page, git_repo: git_repo, app_name: app_name)
                 .deployed_releases
      releases_in_time = releases.select { |r|
        r.production_deploy_time.present? &&
        r.production_deploy_time >= from_date &&
        r.production_deploy_time < to_date
      }
      if releases_in_time.count == releases.count
        puts "STATS WARNING: There maybe more releases for #{app_name}. Increase the incursion-depth."
      end

      total_count = releases_in_time.count
      no_approval_count = releases_in_time.select { |r| r.feature_reviews.empty? }.count
      unapproved_releases = releases_in_time.select { |r| !r.approved? }
      approval_pending_count = unapproved_releases.count - no_approval_count

      puts "STATS INFO: Total releases: #{total_count}"
      puts "STATS INFO: Aproval pending: #{approval_pending_count}"
      puts "STATS INFO: No approval sought: #{no_approval_count}"
      unapproved_releases.each do |release|
        puts "STATS INFO: #{release.version} released by #{release.deployed_by}" if release.deployed_by
      end
      puts 'STATS INFO: *****************'

      total_count_all_apps += total_count
      approval_pending_count_all_apps += approval_pending_count
      no_approval_count_all_apps += no_approval_count
    end

    puts 'STATS INFO: App: all'
    puts "STATS INFO: Total releases: #{total_count_all_apps}"
    puts "STATS INFO: Aproval pending: #{approval_pending_count_all_apps}"
    puts "STATS INFO: No approval sought: #{no_approval_count_all_apps}"
  end
end
