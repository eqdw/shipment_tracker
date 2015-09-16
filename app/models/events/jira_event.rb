require 'events/base_event'

module Events
  class JiraEvent < Events::BaseEvent
    def key
      details.fetch('issue').fetch('key')
    end

    def issue?
      details.fetch('webhookEvent', '').start_with?('jira:issue_')
    end

    def issue_id
      details.fetch('issue').fetch('id')
    end

    def summary
      details.fetch('issue').fetch('fields').fetch('summary')
    end

    def status
      details.fetch('issue').fetch('fields').fetch('status').fetch('name')
    end

    def comment
      details.fetch('comment', {}).fetch('body', '')
    end

    def approval?
      status_item &&
        approved_status?(status_item['toString']) &&
        !approved_status?(status_item['fromString'])
    end

    def unapproval?
      status_item &&
        approved_status?(status_item['fromString']) &&
        !approved_status?(status_item['toString'])
    end

    private

    def status_item
      @status_item ||= changelog_items.find { |item| item['field'] == 'status' }
    end

    def changelog_items
      details.fetch('changelog', 'items' => []).fetch('items')
    end

    def approved_status?(status)
      Rails.application.config.approved_statuses.include?(status)
    end
  end
end
