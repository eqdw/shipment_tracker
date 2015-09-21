class AddIndexForKeyToTickets < ActiveRecord::Migration
  def change
    add_index :tickets, :key
  end
end
