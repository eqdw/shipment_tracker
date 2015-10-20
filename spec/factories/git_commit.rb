require 'git_commit'

# rubocop:disable Style/BlockDelimiters
FactoryGirl.define do
  factory :git_commit do
    sequence(:id) { |n| "abc#{n}" }
    author_name 'Frank'
    message 'A commit'

    initialize_with { new(attributes) }
  end
end
# rubocop:enable Style/BlockDelimiters
