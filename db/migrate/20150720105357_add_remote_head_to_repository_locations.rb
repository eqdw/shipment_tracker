class AddRemoteHeadToRepositoryLocations < ActiveRecord::Migration
  def change
    add_column :repository_locations, :remote_head, :string
  end
end
