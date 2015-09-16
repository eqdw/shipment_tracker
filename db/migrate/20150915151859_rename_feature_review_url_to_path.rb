class RenameFeatureReviewUrlToPath < ActiveRecord::Migration
  def change
    rename_column :feature_reviews, :url, :path
  end
end
