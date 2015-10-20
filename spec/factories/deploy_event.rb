require 'events/deploy_event'

# rubocop:disable Style/BlockDelimiters
FactoryGirl.define do
  factory :deploy_event, class: Events::DeployEvent do
    transient do
      server 'uat.example.com'
      sequence(:version) { |n| "abc#{n}" }
      app_name 'hello_world'
      deployed_at { Time.now.utc.to_i }
      deployed_by 'frank@example.com'
      environment 'uat'
    end

    details {
      {
        'server' => server,
        'version' => version,
        'app_name' => app_name,
        'deployed_at' => deployed_at,
        'deployed_by' => deployed_by,
        'environment' => environment,
      }
    }

    initialize_with { new(attributes) }
  end
end
# rubocop:enable Style/BlockDelimiters
