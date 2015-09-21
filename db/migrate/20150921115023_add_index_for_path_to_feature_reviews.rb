class AddIndexForPathToFeatureReviews < ActiveRecord::Migration
  def change
    add_index :feature_reviews, :path
  end
end
