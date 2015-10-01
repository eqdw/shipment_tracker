# rubocop:disable Style/BlockDelimiters
FactoryGirl.define do
  factory :jira_event, class: Events::JiraEvent do
    transient do
      sequence(:issue_id)
      sequence(:key) { |n| "JIRA-#{n}" }

      summary ''
      display_name 'joe'
      user_email 'joe.bloggs@example.com'
      status 'To Do'
      updated '2015-05-07T15:24:34.957+0100'
      comment_body nil

      changelog_details({})

      default_details do
        {
          'webhookEvent' => 'jira:issue_updated',
          'user' => {
            'displayName' => display_name,
            'emailAddress' => user_email,
          },
          'issue' => {
            'id' => issue_id,
            'key' => key,
            'fields' => {
              'summary' => summary,
              'status' => { 'name' => status },
              'updated' => updated,
            },
          },
        }
      end
    end

    details do
      details = default_details.merge(changelog_details)
      details.merge!('comment' => { 'body' => comment_body }) if comment_body
      details
    end

    initialize_with { new(attributes) }

    trait :created do
      status 'To Do'
    end

    trait :started do
      changelog_details(
        'changelog' => {
          'items' => [
            {
              'field' => 'status',
              'fromString' => 'To Do',
              'toString' => 'In Progress',
            },
          ],
        },
      )
      status 'In Progress'
    end

    trait :development_completed do
      changelog_details(
        'changelog' => {
          'items' => [
            {
              'field' => 'status',
              'fromString' => 'In Progress',
              'toString' => 'Ready For Review',
            },
          ],
        },
      )
      status 'Ready For Review'
    end

    trait :approved do
      changelog_details(
        'changelog' => {
          'items' => [
            {
              'field' => 'status',
              'fromString' => 'Ready For Review',
              'toString' => 'Ready for Deployment',
            },
          ],
        },
      )
      status 'Ready for Deployment'
    end

    trait :deployed do
      changelog_details(
        'changelog' => {
          'items' => [
            {
              'field' => 'status',
              'fromString' => 'Ready for Deployment',
              'toString' => 'Done',
            },
          ],
        },
      )
      status 'Done'
    end

    trait :rejected do
      changelog_details(
        'changelog' => {
          'items' => [
            {
              'field' => 'status',
              'fromString' => 'Ready for Deployment',
              'toString' => 'In Progress',
            },
          ],
        },
      )
      status 'In Progress'
    end
  end

  factory :jira_event_user_created, class: Events::JiraEvent do
    details do
      {
        'timestamp' => 1_434_031_799_536,
        'webhookEvent' => 'user_created',
        'user' => {
          'self' => 'https://jira.example.com/rest/api/2/user?key=john.doe%40example.com',
          'name' => 'john.doe@example.com',
          'key' => 'john.doe@example.com',
          'emailAddress' => 'john.doe@example.com',
          'displayName' => 'John Doe',
        },
      }
    end
  end
end
# rubocop:enable Style/BlockDelimiters
