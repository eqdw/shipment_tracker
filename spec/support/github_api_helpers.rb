module Support
  module GithubApiHelpers
    def github_pr_payload(action:, repo_url:, sha:)
      {
        'action' => action,
        'pull_request' => {
          'head' => {
            'sha' => sha,
          },
          'base' => {
            'repo' => {
              'html_url' => repo_url,
            },
          },
        },
      }
    end
  end
end
