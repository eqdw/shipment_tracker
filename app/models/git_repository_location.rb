class GitRepositoryLocation < ActiveRecord::Base
  validate :must_have_valid_uri

  def must_have_valid_uri
    URI.parse(uri)
  rescue URI::InvalidURIError
    errors.add(:uri, "must be valid in accordance with rfc3986.
      If using the github SSH clone url then amend to match the following format:
      ssh://git@github.com/ORGANIZATION/REPO.git")
  end

  def self.app_names
    all.order(name: :asc).pluck(:name)
  end

  def self.update_from_github_notification(payload)
    ssh_url = payload.fetch('repository', {}).fetch('ssh_url', nil)
    git_repository_location = find_by_github_ssh_url(ssh_url)
    return unless git_repository_location
    git_repository_location.update(remote_head: payload['after'])
  end

  def self.find_by_github_ssh_url(url)
    path = Addressable::URI.parse(url).try(:path)
    find_by('uri LIKE ?', "%#{path}")
  end
  private_class_method :find_by_github_ssh_url
end
