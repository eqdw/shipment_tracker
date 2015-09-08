class AddEnvironmentToDeploys < ActiveRecord::Migration
  def change
    add_column :deploys, :environment, :string
  end
end
