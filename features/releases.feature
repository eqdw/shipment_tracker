@logged_in
Feature: Viewing Releases
  As a deployer
  I want to view all releases for a given application
  So I know which versions are safe to deploy and which versions have already been deployed

Scenario: Viewing releases for an app
  Given an application called "frontend"
  And a ticket "JIRA-789" with summary "Old ticket" is started
  And a ticket "JIRA-123" with summary "Urgent ticket" is started
  And a ticket "JIRA-456" with summary "Not so urgent ticket" is started
  And a commit "#master1" with message "historic commit" is created at "00:01:17"
  And developer prepares review known as "FR_789" for UAT "uat.example.com" with apps
    | app_name | version  |
    | frontend | #master1 |
  And at time "01:02:00" adds link for review "FR_789" to comment for ticket "JIRA-789"
  And ticket "JIRA-789" is approved by "jeff@fundingcircle.com" at "01:03:45"
  And the branch "feature" is checked out
  And a commit "#branch1" with message "first commit" is created at "02:01:17"
  And a commit "#branch2" with message "second commit" is created at "02:04:19"
  And commit "#branch2" of "frontend" is deployed by "Alice" to server "uat.fundingcircle.com"
  And developer prepares review known as "FR_123" for UAT "uat.fundingcircle.com" with apps
    | app_name | version  |
    | frontend | #branch1 |
  And at time "03:12:45" adds link for review "FR_123" to comment for ticket "JIRA-123"
  And developer prepares review known as "FR_456" for UAT "uat.example.com" with apps
    | app_name | version  |
    | frontend | #branch2 |
  And at time "03:19:53" adds link for review "FR_456" to comment for ticket "JIRA-456"
  And ticket "JIRA-456" is approved by "bob@fundingcircle.com" at "03:24:34"
  And the branch "master" is checked out
  And a commit "#master2" with message "sneaky commit" is created at "04:01:02"
  And commit "#master2" of "frontend" is deployed by "Charlotte" to production at "04:54:20"
  And the branch "feature" is merged with merge commit "#merge" at "05:04:19"

  When I view the releases for "frontend"

  Then I should see the "pending" releases
    | version  | subject                        | feature reviews | review statuses     | approved | committed to master at |
    | #merge   | Merged `feature` into `master` | FR_456          | approved            | yes      | 05:04                  |
    | #branch2 | second commit                  | FR_456          | approved            | yes      | 05:04                  |
    | #branch1 | first commit                   | FR_123, FR_456  | unapproved approved | yes      | 05:04                  |

  And I should see the "deployed" releases
    | version      | subject                    | feature reviews | review statuses     | approved | committed to master at | last deployed at |
    | #master2     | sneaky commit              |                 |                     | no       | 04:01                  | 04:54            |
    | #master1     | historic commit            |                 |                     | no       | 00:01                  |                  |
