Feature:
  Developer prepares a Feature Review so that it can be attached to a ticket for a PO to use in acceptance.

Background:
  Given an application called "frontend"
  And an application called "backend"
  And an application called "mobile"
  And an application called "irrelevant"

@logged_in
Scenario: Preparing a Feature Review
  Given a commit "#abc" by "Alice" is created for app "frontend"
  And a commit "#def" by "Bob" is created for app "backend"
  When I prepare a feature review for:
    | field name      | content             |
    | frontend        | #abc                |
    | backend         | #def                |
    | UAT environment | http://www.some.url |
  Then I should see the feature review page with the applications:
    | app_name | version |
    | frontend | #abc    |
    | backend  | #def    |
  And I can see the UAT environment "http://www.some.url"

@logged_in
Scenario: Viewing User Acceptance Tests results on a Feature review
  Given a commit "#abc" by "Alice" is created for app "frontend"
  And a commit "#def" by "Bob" is created for app "backend"
  And commit "#abc" of "frontend" is deployed by "Alice" to server "uat.fundingcircle.com"
  And commit "#def" of "backend" is deployed by "Bob" to server "uat.fundingcircle.com"
  And developer prepares review known as "FR_visit" for UAT "uat.fundingcircle.com" with apps
    | app_name | version |
    | frontend | #abc    |
    | backend  | #def    |
  And User Acceptance Tests at version "abc123" which "passed" on server "uat.fundingcircle.com"
  And User Acceptance Tests at version "abc123" which "failed" on server "other-uat.fundingcircle.com"

  When I visit the feature review known as "FR_visit"

  Then I should see a summary that includes
    | status  | title                 |
    | success | User Acceptance Tests |

  And I should see the results of the User Acceptance Tests with heading "success" and version "abc123"

@logged_in
Scenario: Viewing a feature review
  Given a ticket "JIRA-123" with summary "Urgent ticket" is started
  And a commit "#abc" by "Alice" is created for app "frontend"
  And a commit "#old" by "Bob" is created for app "backend"
  And a commit "#def" by "Bob" is created for app "backend"
  And a commit "#ghi" by "Carol" is created for app "mobile"
  And a commit "#xyz" by "Wendy" is created for app "irrelevant"
  And CircleCi "passes" for commit "#abc"
  And CircleCi "fails" for commit "#def"
  # Flaky tests, build retriggered.
  And CircleCi "passes" for commit "#def"
  And commit "#abc" of "frontend" is deployed by "Alice" to server "uat.fundingcircle.com"
  And commit "#old" of "backend" is deployed by "Bob" to server "uat.fundingcircle.com"
  And commit "#def" of "backend" is deployed by "Bob" to server "other-uat.fundingcircle.com"
  And commit "#xyz" of "irrelevant" is deployed by "Wendy" to server "uat.fundingcircle.com"
  And developer prepares review known as "FR_view" upto now for UAT "uat.fundingcircle.com" with apps
    | app_name | version |
    | frontend | #abc    |
    | backend  | #def    |
    | mobile   | #ghi    |
  And at time "00:00:01" adds link for review "FR_view" to comment for ticket "JIRA-123"

  When I visit the feature review known as "FR_view"

  Then I should see a summary with heading "danger" and content
    | status  | title                 |
    | warning | Test Results          |
    | failed  | UAT Environment       |
    | warning | QA Acceptance         |
    | warning | User Acceptance Tests |

  And I should only see the ticket
    | Key      | Summary       | Status      |
    | JIRA-123 | Urgent ticket | In Progress |

  And I should see the builds with heading "warning" and content
    | Status  | App      | Source   |
    | success | frontend | CircleCi |
    | success | backend  | CircleCi |
    | warning | mobile   |          |

  And I should see the deploys to UAT with heading "danger" and content
    | App      | Version | Correct |
    | frontend | #abc    | yes     |
    | backend  | #old    | no      |

  And I should see the time when the Feature Review is for

Scenario: QA rejects feature
  Given I am logged in as "foo@bar.com"
  And developer prepares review known as "FR_qa_rejects" for UAT "uat.fundingcircle.com" with apps
    | app_name | version |
    | frontend | abc     |
    | backend  | def     |
  When I visit the feature review known as "FR_qa_rejects"
  Then I should see the QA acceptance with heading "warning"

  When I "reject" the feature with comment "Not good enough"

  Then I should see an alert: "Thank you for your submission. It will appear in a moment."

  When I reload the page after a while
  Then I should see the QA acceptance
    | status  | email       | comment         |
    | danger  | foo@bar.com | Not good enough |

  When I "accept" the feature with comment "Superb!"

  And I reload the page after a while
  Then I should see the QA acceptance
    | status  | email       | comment |
    | success | foo@bar.com | Superb! |
