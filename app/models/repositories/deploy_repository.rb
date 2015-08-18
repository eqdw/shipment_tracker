require 'events/deploy_event'
require 'snapshots/deploy'

module Repositories
  class DeployRepository
    def initialize(store = Snapshots::Deploy)
      @store = store
    end

    delegate :table_name, to: :store

    def deploys_for(apps: nil, server:, at: nil)
      deploys(apps, server, at)
    end

    def deploys_for_versions(versions, environment:)
      query = store.select('DISTINCT ON (version) *')
      query = query.where(store.arel_table['version'].in(versions))
      query = query.where(environment: environment)
      query.order('version, id DESC').map { |deploy_record|
        Deploy.new(deploy_record.attributes)
      }
    end

    def apply(event)
      return unless event.is_a?(Events::DeployEvent)

      store.create!(
        app_name: event.app_name,
        server: event.server,
        environment: event.environment,
        version: event.version,
        deployed_by: event.deployed_by,
        event_created_at: event.created_at,
      )
    end

    private

    attr_reader :store

    def deploys(apps, server, at)
      query = store.select('DISTINCT ON (server, app_name) *').where(server: server)
      query = query.where(store.arel_table['event_created_at'].lteq(at)) if at
      query = query.where(store.arel_table['app_name'].in(apps.keys)) if apps
      query.order('server, app_name, id DESC').map { |deploy_record|
        build_deploy(deploy_record.attributes, apps)
      }
    end

    def build_deploy(deploy_attr, apps)
      correct = apps.present? && deploy_attr.fetch('version') == apps[deploy_attr.fetch('app_name')]
      Deploy.new(deploy_attr.merge(correct: correct))
    end
  end
end
