Feature:
  Developer prepares a Feature Review so that it can be attached to a ticket for a PO to use in acceptance.

Background:
  Given an application called "frontend"
  And an application called "backend"
  And an application called "mobile"
  And an application called "irrelevant"

@logged_in
Scenario: Preparing a Feature Review
  # 2014-10-04
  Given a commit "#abc" by "Alice" is created at "2014-10-04 11:00:00" for app "frontend"
  And a commit "#def" by "Bob" is created at "2014-10-04 12:30:00" for app "backend"

  # Today
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
  # 2014-10-04
  Given a commit "#abc" by "Alice" is created at "2014-10-04 09:00:00" for app "frontend"
  And commit "#abc" of "frontend" is deployed by "Alice" to server "uat.fundingcircle.com" at "2014-10-04 12:00:00"

  # 2014-10-05
  And a commit "#def" by "Bob" is created at "2014-10-05 10:00:00" for app "backend"
  And commit "#def" of "backend" is deployed by "Bob" to server "uat.fundingcircle.com" at "2014-10-05 11:00:00"
  And developer prepares review known as "FR_visit" for UAT "uat.fundingcircle.com" with apps
    | app_name | version |
    | frontend | #abc    |
    | backend  | #def    |

  # 2014-10-06
  And User Acceptance Tests at version "abc123" which "passed" on server "uat.fundingcircle.com" at "2014-10-06 11:00:00"
  And User Acceptance Tests at version "abc123" which "failed" on server "other-uat.fundingcircle.com" at "2014-10-06 11:03:25"

  # Today
  When I visit the feature review known as "FR_visit"
  Then I should see a summary that includes
    | status  | title                 |
    | success | User Acceptance Tests |
  And I should see the results of the User Acceptance Tests with heading "success" and version "abc123"

@logged_in
Scenario: Viewing a feature review
  # 2014-10-04
  Given a ticket "JIRA-123" with summary "Urgent ticket" is started at "2014-10-04 13:01:17"

  # 2014-10-05
  And a commit "#abc" by "Alice" is created at "2014-10-05 11:01:00" for app "frontend"
  And a commit "#old" by "Bob" is created at "2014-10-05 11:02:00" for app "backend"
  And a commit "#def" by "Bob" is created at "2014-10-05 11:03:00" for app "backend"
  And a commit "#ghi" by "Carol" is created at "2014-10-05 11:04:00" for app "mobile"
  And a commit "#xyz" by "Wendy" is created at "2014-10-05 11:05:00" for app "irrelevant"
  And At "2014-10-05 12:00:00" CircleCi "passes" for commit "#abc"
  And At "2014-10-05 12:05:00" CircleCi "fails" for commit "#def"
  # Build retriggered and passes second time.
  And At "2014-10-05 12:23:00" CircleCi "passes" for commit "#def"
  And commit "#abc" of "frontend" is deployed by "Alice" to server "uat.fundingcircle.com" at "2014-10-05 13:00:00"
  And commit "#old" of "backend" is deployed by "Bob" to server "uat.fundingcircle.com" at "2014-10-05 13:11:00"
  And commit "#def" of "backend" is deployed by "Bob" to server "other-uat.fundingcircle.com" at "2014-10-05 13:48:00"
  And commit "#xyz" of "irrelevant" is deployed by "Wendy" to server "uat.fundingcircle.com" at "2014-10-05 14:05:00"
  And developer prepares review known as "FR_view" for UAT "uat.fundingcircle.com" with apps
    | app_name | version |
    | frontend | #abc    |
    | backend  | #def    |
    | mobile   | #ghi    |
  And at time "2014-10-05 16:00:01" adds link for review "FR_view" to comment for ticket "JIRA-123"
  And ticket "JIRA-123" is approved by "jim@fundingcircle.com" at "2014-10-05 17:30:10"

  When I visit the feature review known as "FR_view"

  Then I should see that the Feature Review was approved at "2014-10-05 17:30:10"

  And I should only see the ticket
    | Ticket   | Summary       | Status               |
    | JIRA-123 | Urgent ticket | Ready for Deployment |

  And I should see a summary with heading "danger" and content
    | status  | title                 |
    | warning | Test Results          |
    | failed  | UAT Environment       |
    | warning | QA Acceptance         |
    | warning | User Acceptance Tests |

  And I should see the builds with heading "warning" and content
    | Status  | App      | Source   |
    | success | frontend | CircleCi |
    | success | backend  | CircleCi |
    | warning | mobile   |          |

  And I should see the deploys to UAT with heading "danger" and content
    | App      | Version | Correct |
    | frontend | #abc    | yes     |
    | backend  | #old    | no      |

@logged_in
Scenario: Viewing a feature review as at a specified time
  Given a ticket "JIRA-123" with summary "Urgent ticket" is started at "2014-10-04 13:00:00"
  And a commit "#abc" by "Alice" is created at "2014-10-04 13:05:00" for app "frontend"
  And developer prepares review known as "FR_123" for UAT "uat.fundingcircle.com" with apps
    | app_name | version |
    | frontend | #abc    |
  And at time "2014-10-04 14:00:00.500" adds link for review "FR_123" to comment for ticket "JIRA-123"

  When I visit feature review "FR_123" as at "2014-10-04 14:00:00"

  Then I should only see the ticket
    | Ticket      | Summary       | Status      |
    | JIRA-123 | Urgent ticket | In Progress |

  And I should see the time "2014-10-04 14:00:00" for the Feature Review

  @logged_in
  Scenario: Viewing an approved feature review before and after approval
    Given a ticket "JIRA-123" with summary "Urgent ticket" is started at "2014-10-04 13:00:00"
    And a commit "#abc" by "Alice" is created at "2014-10-04 13:05:00" for app "frontend"
    And developer prepares review known as "FR_123" for UAT "uat.fundingcircle.com" with apps
      | app_name | version |
      | frontend | #abc    |
    And at time "2014-10-04 14:00:00.500" adds link for review "FR_123" to comment for ticket "JIRA-123"
    And ticket "JIRA-123" is approved by "jim@fundingcircle.com" at "2014-10-05 17:30:10"

    When I visit feature review "FR_123" as at "2014-10-04 15:00:00"
    Then I should see that the Feature Review was not approved
    Then I should only see the ticket
      | Ticket   | Summary       | Status      |
      | JIRA-123 | Urgent ticket | In Progress |

    When I visit feature review "FR_123" as at "2014-10-06 10:00:00"
    Then I should see that the Feature Review was approved at "2014-10-05 17:30:10"
    And I should only see the ticket
      | Ticket   | Summary       | Status               |
      | JIRA-123 | Urgent ticket | Ready for Deployment |


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
