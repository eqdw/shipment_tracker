class JiraEvent < Event
  # def self.find_all_for_versions(versions)
  #   where("details -> 'payload' ->> 'vcs_revision' in (?)", versions)
  # end

  def key
    details.fetch('issue').fetch('key')
  end

  def summary
    details.fetch('issue').fetch('fields').fetch('summary')
  end

  def status
    details.fetch('issue').fetch('fields').fetch('status').fetch('name')
  end

  def user_email
    details.fetch('user').fetch('emailAddress')
  end

  def status_changed_to?(final_status)
    status_changed? && status == final_status
  end

  private

  def status_changed?
    details.fetch('changelog').fetch('items').any? do |item|
      item['field'] == 'status'
    end
  end
end