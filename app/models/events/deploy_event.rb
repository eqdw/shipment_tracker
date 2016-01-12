require 'events/base_event'

module Events
  class DeployEvent < Events::BaseEvent
    ENVIRONMENTS = %w(uat staging production)

    def app_name
      (details['app_name'] || details['app']).try(:downcase)
    end

    def server
      servers.first
    end

    def version
      details['version'] || details['head_long']
    end

    def deployed_by
      details['deployed_by'] || details['user']
    end

    def environment
      details.fetch('environment', heroku_environment)
    end

    private

    def heroku_environment
      app_name_extension if ENVIRONMENTS.include?(app_name_extension)
    end

    def app_name_extension
      return nil unless app_name
      app_name.split('-').last
    end

    def servers
      details.fetch('servers', servers_fallback)
    end

    def servers_fallback
      [details['server'] || details['url']].compact
    end
  end
end
