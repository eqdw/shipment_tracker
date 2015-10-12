require 'octokit'

class GitRepositoryLocation < ActiveRecord::Base
  before_validation on: :create do
    self.uri = convert_remote_uri(uri)
  end

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

  def self.uris
    all.pluck(:uri)
  end

  def self.github_url_for_app(app_name)
    repo_location = find { |r| r.name == app_name }
    return unless repo_location
    Octokit::Repository.from_url(repo_location.uri).url.chomp('.git')
  end

  def self.github_urls_for_apps(app_names)
    github_urls = {}
    app_names.each do |app_name|
      github_urls[app_name] = github_url_for_app(app_name)
    end
    github_urls
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

  private

  def convert_remote_uri(remote_url)
    return remote_url unless remote_url.start_with?('git@')
    domain, path = remote_url.match(/git@(.*):(.*)/).captures
    "ssh://git@#{domain}/#{path}"
  rescue NoMethodError
    remote_url
  end
end
