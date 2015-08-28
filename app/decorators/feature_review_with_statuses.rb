require 'forwardable'

class FeatureReviewWithStatuses < SimpleDelegator
  extend Forwardable

  def_delegators :@query, :tickets, :builds, :deploys, :qa_submission, :uatest

  attr_reader :time

  def initialize(feature_review, at: Time.now, query_class: Queries::FeatureReviewQuery)
    super(feature_review)
    @feature_review = feature_review
    @time = at
    @query = query_class.new(feature_review, at: @time)
  end

  def build_status
    builds = query.builds.values

    return nil if builds.empty?

    if builds.all? { |b| b.success == true }
      :success
    elsif builds.any? { |b| b.success == false }
      :failure
    end
  end

  def deploy_status
    deploys = query.deploys
    return nil if deploys.empty?
    deploys.all?(&:correct) ? :success : :failure
  end

  def qa_status
    qa_submission = query.qa_submission
    return nil unless qa_submission
    qa_submission.accepted ? :success : :failure
  end

  def uatest_status
    uatest = query.uatest
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

  def approved?
    tickets = query.tickets
    return false if tickets.empty?
    tickets.all?(&:approved?)
  end

  def approval_status
    approved? ? :approved : :unapproved
  end

  private

  attr_reader :feature_review, :query
end
