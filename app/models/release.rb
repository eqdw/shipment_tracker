require 'virtus'

class Release
  include Virtus.value_object

  values do
    attribute :commit, GitCommit
    attribute :production_deploy_time, Time
    attribute :subject, String
    attribute :feature_reviews, Array
  end

  def version
    commit.id
  end

  def approved?
    feature_reviews.any?(&:approved?)
  end
end
