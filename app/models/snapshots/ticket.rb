require 'active_record'

module Snapshots
  class Ticket < ActiveRecord::Base
    def self.most_recent_snapshot(key = nil)
      return last if key.nil?
      where(key: key).last
    end
  end
end
