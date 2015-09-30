class DropFeatureReviews < ActiveRecord::Migration
  def up
    drop_table :feature_reviews
  end

  def down
    create_table :feature_reviews do |t|
      t.string :path
      t.string :versions, array: true
      t.datetime :event_created_at
      t.datetime :approved_at
    end

    add_index :feature_reviews, :path
    add_index(:feature_reviews, :versions, using: 'gin')
  end
end
