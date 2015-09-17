module Payloads
  class PullRequest
    def initialize(data)
      @data = data
    end

    def head_sha
      pull_request.fetch('head', {})['sha']
    end

    def base_repo_url
      pull_request.fetch('base', {}).fetch('repo', {})['html_url']
    end

    def action
      data['action']
    end

    private

    attr_reader :data

    def pull_request
      data.fetch('pull_request', {})
    end
  end
end
