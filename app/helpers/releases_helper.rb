module ReleasesHelper
  def feature_review_link(feature_review)
    path = feature_review.approved_path || feature_review.path_with_query_time
    link_to(feature_review.approval_status, path)
  end
end
