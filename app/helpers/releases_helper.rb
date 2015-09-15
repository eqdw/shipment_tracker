module ReleasesHelper
  def feature_review_link(feature_review)
    if feature_review.approved_path
      path = feature_review.approved_path
      msg = 'View Feature Review at approval time'
    else
      path = feature_review.path_with_query_time
      msg = 'View Feature Review when committed to master'
    end
    link_to(feature_review.approval_status, path, data: { toggle: 'tooltip' }, title: msg)
  end
end
