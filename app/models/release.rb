require 'virtus'

class Release
  include Virtus.value_object

  values do
    attribute :version, String
    attribute :production_deploy_time, Time
    attribute :subject, String
  end
end
