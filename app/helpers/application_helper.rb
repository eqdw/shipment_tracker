module ApplicationHelper
  def title(title_text = nil, &block)
    haml_tag('h1.title', title_text, &block)
  end

  def short_sha(full_sha)
    full_sha[0...7]
  end

  def commit_link(version, github_repo_url)
    github_commit_url = "#{github_repo_url}/commit/#{version}"
    link_to short_sha(version), github_commit_url, target: '_blank'
  end

  def pull_request_link(commit_subject, github_repo_url)
    pull_request_num = commit_subject.scan(/pull request #(\d+)/).first.try(:first)
    if pull_request_num
      github_pull_request_url = "#{github_repo_url}/pull/#{pull_request_num}"
      pull_request_text = "pull request ##{pull_request_num}"
      link = link_to pull_request_text, github_pull_request_url, target: '_blank'
      commit_subject.sub(pull_request_text, link)
    else
      commit_subject
    end
  end

  # Convenience method for working with ActiveModel::Errors.
  def error_message(attribute, message)
    return message.to_sentence if attribute == :base
    "#{attribute}: #{message.to_sentence}"
  end
end
