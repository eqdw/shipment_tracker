require 'virtus'

class Release
  include Virtus.value_object

  values do
    attribute :commit, GitCommit
    attribute :production_deploy_time, Time
    attribute :subject, String
  end

  def version
    commit.id
  end
end
