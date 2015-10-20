require 'events/jenkins_event'

# rubocop:disable Style/BlockDelimiters
FactoryGirl.define do
  factory :jenkins_event, class: Events::JenkinsEvent do
    transient do
      success? true
      sequence(:version)
    end

    details {
      {
        'build' => {
          'scm' => {
            'commit' => version,
          },
          'status' => success? ? 'SUCCESS' : 'FAILURE',
        },
      }
    }

    initialize_with { new(attributes) }
  end
end
# rubocop:enable Style/BlockDelimiters
