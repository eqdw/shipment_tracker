class PullRequestUpdateJob < ActiveJob::Base
  queue_as :default

  def perform(opts)
    PullRequestStatus.new.update(opts)
  end
end
