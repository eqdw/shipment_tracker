@logged_in
Feature: Auditor searches a Feature Review.

Background:
  # 2014-10-03
  Given an application called "frontend"
  And a commit "#master1" with message "initial commit" is created at "2014-10-03 17:01:37"

  # 2014-10-04
  And a ticket "JIRA-123" with summary "Urgent ticket" is started at "2014-10-04 09:01:28"

  # 2014-10-05
  And the branch "feature-one" is checked out
  And a commit "#commit1" with message "first commit" is created at "2014-10-05 14:26:03"
  And developer prepares review known as "FR_search1" for UAT "http://uat.fundingcircle.com" with apps
    | app_name | version  |
    | frontend | #commit1 |
  And at time "2014-10-05 14:20:13" adds link for review "FR_search1" to comment for ticket "JIRA-123"

  # 2014-10-06
  And the branch "feature-one" is checked out
  And a commit "#commit2" with message "second commit" is created at "2014-10-06 15:04:19"
  And developer prepares review known as "FR_search2" for UAT "http://uat.fundingcircle.com" with apps
    | app_name | version  |
    | frontend | #commit2 |
  And at time "2014-10-06 16:21:34" adds link for review "FR_search2" to comment for ticket "JIRA-123"

  # 2014-10-07
  And ticket "JIRA-123" is approved by "alice@fundingcircle.com" at "2014-10-07 09:44:34"

  # 2014-10-08
  And the branch "master" is checked out
  And a commit "#commit3" with message "recent commit" is created at "2014-10-08 13:31:17"

  # 2014-10-09
  And the branch "master" is checked out
  And the branch "feature-one" is merged with merge commit "#merge" at "2014-10-09 16:04:19"

Scenario: Searching for a Feature Review
  When I look up feature reviews for "#commit1" on "frontend"
  Then I should see the feature review known as "FR_search" for
    | app_name | version  | uat                          |
    | frontend | #commit1 | http://uat.fundingcircle.com |
    | frontend | #commit2 | http://uat.fundingcircle.com |
  And I select link to feature review "2"
  Then I should see the feature review page with the applications:
    | app_name | version  |
    | frontend | #commit2 |

Scenario: Searching for a commit with no associated Feature Reviews
  When I look up feature reviews for "#master1" on "frontend"
  Then I should see an alert: "No Feature Reviews found."
