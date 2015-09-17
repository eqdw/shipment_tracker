require 'active_record'

module Snapshots
  class FeatureReview < ActiveRecord::Base
    def self.most_recent_snapshot(path = nil)
      return last if path.nil?
      where(path: path).last
    end
  end
end
