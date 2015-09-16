module ReleasesHelper
  def feature_review_link(feature_review)
    if feature_review.approved_path
      link_to(
        feature_review.approval_status,
        feature_review.approved_path,
        data: { toggle: 'tooltip' },
        title: 'View Feature Review at approval time',
      )
    else
      link_to(feature_review.approval_status, feature_review.path)
    end
  end
end
