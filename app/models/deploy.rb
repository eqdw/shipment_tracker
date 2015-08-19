class Deploy
  include Virtus.value_object

  values do
    attribute :app_name, String
    attribute :server, String
    attribute :version, String
    attribute :deployed_by, String
    attribute :correct, Boolean
    attribute :event_created_at, DateTime
  end
end
