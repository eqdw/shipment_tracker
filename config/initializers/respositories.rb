Rails.configuration.repositories = [
  Repositories::DeployRepository.new,
  Repositories::BuildRepository.new,
  Repositories::ManualTestRepository.new,
  Repositories::TicketRepository.new,

  # FeatureReviewRepository must always be after TicketRepository
  # because the feature review must check whether its status changes
  # which depends on the ticket statuses.
  Repositories::FeatureReviewRepository.new,

  # UatestRepository must always be last as it depends on DeployRepository.
  # Until we make snapshot updating more robust (e.g. jobs queue or table locking) this will have to remain.
  Repositories::UatestRepository.new,
]
