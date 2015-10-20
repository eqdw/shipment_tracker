require 'events/uat_event'

# rubocop:disable Style/BlockDelimiters
FactoryGirl.define do
  factory :uat_event, class: Events::UatEvent do
    transient do
      success true
      sequence(:test_suite_version)
      server 'uat.fundingcircle.com'
    end

    details {
      {
        'success' => success,
        'test_suite_version' => test_suite_version,
        'server' => server,
      }
    }

    initialize_with { new(attributes) }
  end
end
# rubocop:enable Style/BlockDelimiters
