class AddApprovedAtToTickets < ActiveRecord::Migration
  def change
    add_column :tickets, :approved_at, :datetime
  end
end
