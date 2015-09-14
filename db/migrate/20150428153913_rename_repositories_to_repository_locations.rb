class RenameRepositoriesToRepositoryLocations < ActiveRecord::Migration
  def change
    rename_table :repositories, :repository_locations
  end
end
