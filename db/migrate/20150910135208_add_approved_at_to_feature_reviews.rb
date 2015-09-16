class AddApprovedAtToFeatureReviews < ActiveRecord::Migration
  def change
    add_column :feature_reviews, :approved_at, :datetime
  end
end
