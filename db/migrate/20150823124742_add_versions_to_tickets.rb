class AddVersionsToTickets < ActiveRecord::Migration
  def change
    add_column :tickets, :versions, :string, array: true
    add_index :tickets, :versions, using: 'gin'
    add_index :deploys, :version
  end
end
