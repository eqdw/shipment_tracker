namespace :stats do
  desc 'Counts releases'
  task :approved_releases, [:from_date, :to_date, :per_page] => :environment do |_, args|
    args.with_defaults(date_from: nil, date_to: nil, per_page: 50)
    to_date = args.to_date ? Time.parse(args.to_date) : Time.current.beginning_of_day
    from_date = args.from_date ? Time.parse(args.from_date) : to_date - 7.days
    per_page = args.per_page.to_i

    puts "STATS INFO: Evaluating releases from #{from_date.strftime('%F')} until #{to_date.strftime('%F')}"
    puts "STATS INFO: Incursion-depth: last #{per_page} commits"

    unapproved_count_all_apps = 0
    total_count_all_apps = 0

    GitRepositoryLocation.app_names.each do |app_name|
      puts "STATS INFO: Evaluating app: #{app_name}"
      git_repo = GitRepositoryLoader.from_rails_config.load(app_name)
      query = Queries::ReleasesQuery.new(per_page: per_page, git_repo: git_repo, app_name: app_name)
      releases = query.deployed_releases

      versions = query.versions

      store = Snapshots::Deploy
      query = store.select('DISTINCT ON (version) *')
      query = query.where(store.arel_table['app_name'].eq(app_name))
      query = query.where(store.arel_table['version'].not_in(versions))
      query = query.where(store.arel_table['event_created_at'].between(from_date..to_date))
      query = query.where(environment: 'production')
      deploys_on_non_master = query.order('version, id DESC').map { |deploy_record|
        Deploy.new(deploy_record.attributes)
      }

      releases_with_inherit = []

      releases.each do |release|
        if release.production_deploy_time.present?
          releases_with_inherit << release
        elsif !release.approved? && !releases_with_inherit.empty?
          last_release = releases_with_inherit.pop
          releases_with_inherit << Release.new(last_release.attributes.merge(feature_reviews: []))
        end
      end

      releases_in_time = releases_with_inherit.select { |r|
        r.production_deploy_time.present? &&
        r.production_deploy_time >= from_date &&
        r.production_deploy_time < to_date
      }
      if releases_in_time.count == releases.count
        puts "STATS WARNING: There maybe more releases for #{app_name}. Increase the incursion-depth."
      end

      total_count = releases_in_time.count
      unapproved_releases = releases_in_time.select { |r| !r.approved? }
      unapproved_count = unapproved_releases.count

      puts "STATS INFO: Total releases: #{total_count}"
      puts "STATS INFO: Unapproved releases: #{unapproved_count}" if unapproved_releases.present?
      unapproved_releases.each do |release|
        puts "STATS INFO: #{release.version} released by #{release.deployed_by}"
      end
      # rubocop:disable LineLength
      puts "STATS INFO: Releases of commits not on master: #{deploys_on_non_master.count}" if deploys_on_non_master.present?
      deploys_on_non_master.each do |deploy|
        puts "STATS INFO: #{deploy.version} released by #{deploy.deployed_by}"
      end
      # rubocop:enable LineLength

      puts 'STATS INFO: *****************'

      total_count_all_apps += total_count
      unapproved_count_all_apps += unapproved_count
    end

    puts 'STATS INFO: App: all'
    puts "STATS INFO: Total releases: #{total_count_all_apps}"
    puts "STATS INFO: Unapproved releases: #{unapproved_count_all_apps}"
  end
end
