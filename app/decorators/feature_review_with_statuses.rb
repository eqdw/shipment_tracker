class FeatureReviewWithStatuses < SimpleDelegator
  attr_reader :builds, :deploys, :qa_submission, :tickets, :uatest, :time

  def initialize(feature_review, builds:, deploys:, qa_submission:, tickets:, uatest:, at:)
    super(feature_review)
    @time = at
    @builds = builds
    @deploys = deploys
    @qa_submission = qa_submission
    @tickets = tickets
    @uatest = uatest
  end

  def build_status
    build_values = builds.values

    return nil if build_values.empty?

    if build_values.all? { |b| b.success == true }
      :success
    elsif build_values.any? { |b| b.success == false }
      :failure
    end
  end

  def deploy_status
    return nil if deploys.empty?
    deploys.all?(&:correct) ? :success : :failure
  end

  def qa_status
    return nil unless qa_submission
    qa_submission.accepted ? :success : :failure
  end

  def uatest_status
    return nil unless uatest
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
end
