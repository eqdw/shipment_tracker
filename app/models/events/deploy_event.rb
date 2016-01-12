require 'events/base_event'

module Events
  class DeployEvent < Events::BaseEvent
    def app_name
      details.fetch('app_name', details.fetch('app', nil)).try(:downcase)
    end

    def server
      servers.first
    end

    def version
      details.fetch('version', details.fetch('head_long', nil))
    end

    def deployed_by
      details.fetch('deployed_by', details.fetch('user', nil))
    end

    def environment
      details.fetch('environment', nil)
    end

    private

    def servers
      details.fetch('servers', servers_fallback)
    end

    def servers_fallback
      [details.fetch('server', details.fetch('url', nil))].compact
    end
  end
end
