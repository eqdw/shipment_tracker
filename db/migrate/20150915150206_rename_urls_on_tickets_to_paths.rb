class RenameUrlsOnTicketsToPaths < ActiveRecord::Migration
  def change
    rename_column :tickets, :urls, :paths
  end
end
