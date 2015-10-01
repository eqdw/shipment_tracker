class FeatureReviewWithStatuses < SimpleDelegator
  attr_reader :builds, :deploys, :qa_submission, :tickets, :uatest, :time

  # rubocop:disable Metrics/LineLength, Metrics/ParameterLists
  def initialize(feature_review, builds: {}, deploys: [], qa_submission: nil, tickets: [], uatest: nil, at: nil)
    super(feature_review)
    @time = at
    @builds = builds
    @deploys = deploys
    @qa_submission = qa_submission
    @tickets = tickets
    @uatest = uatest
  end
  # rubocop:enable Metrics/LineLength, Metrics/ParameterLists

  def build_status
    build_results = builds.values

    return if build_results.empty?

    if build_results.all? { |b| b.success == true }
      :success
    elsif build_results.any? { |b| b.success == false }
      :failure
    end
  end

  def deploy_status
    return if deploys.empty?
    deploys.all?(&:correct) ? :success : :failure
  end

  def qa_status
    return unless qa_submission
    qa_submission.accepted ? :success : :failure
  end

  def uatest_status
    return unless uatest
    uatest.success ? :success : :failure
  end

  def summary_status
    statuses = [deploy_status, qa_status, build_status]

    if statuses.all? { |status| status == :success }
      :success
    elsif statuses.any? { |status| status == :failure }
      :failure
    end
  end

  def approved_at
    return unless approved?
    @approved_at ||= tickets.map(&:approved_at).max
  end

  def approved?
    @approved ||= tickets.present? && tickets.all?(&:approved?)
  end

  def approval_status
    approved? ? :approved : :not_approved
  end

  def approved_path
    "#{base_path}?#{query_hash.merge(time: approved_at.utc).to_query}" if approved?
  end
end
