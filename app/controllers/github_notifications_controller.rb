require 'pull_request_status'

class GithubNotificationsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    if pull_request?
      process_pull_request
      head :ok
    elsif push?
      GitRepositoryLocation.update_from_github_notification(request.request_parameters)
      head :ok
    else
      head :accepted
    end
  end

  private

  def unauthenticated_strategy
    self.status = 403
    self.response_body = 'Forbidden'
  end

  def github_event
    request.env['HTTP_X_GITHUB_EVENT']
  end

  def pull_request?
    github_event == 'pull_request'
  end

  def push?
    github_event == 'push'
  end

  def process_pull_request
    return unless relevant_pull_request?

    status_options = {
      repo_url: payload.base_repo_url,
      sha: payload.head_sha,
    }

    PullRequestStatus.new.reset(status_options)
    PullRequestUpdateJob.perform_later(status_options)
  end

  def relevant_pull_request?
    (payload.action == 'opened' || payload.action == 'synchronize') && audited_repo?
  end

  def audited_repo?
    inferred_repo_name = payload.base_repo_url.split('/').last
    GitRepositoryLocation.uris.any? { |uri| uri.include?(inferred_repo_name) }
  end

  def payload
    @payload ||= Payloads::PullRequest.new(params[:github_notification])
  end
end
