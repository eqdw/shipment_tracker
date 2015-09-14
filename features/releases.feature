@logged_in
Feature: Viewing Releases
  As a deployer
  I want to view all releases for a given application
  So I know which versions are safe to deploy and which versions have already been deployed

Scenario: Viewing releases for an app
  # 2014-09-29
  Given an application called "frontend"
  And a commit "#master1" with message "initial commit" is created at "2014-09-29 09:18:57"
  And commit "#master1" of "frontend" is deployed by "Fred" to production at "2014-09-29 11:37:13"

  # 2014-09-30
  And a ticket "JIRA-789" with summary "Old ticket" is started at "2014-09-30 13:01:17"
  And a ticket "JIRA-123" with summary "Urgent ticket" is started at "2014-09-30 14:31:46"
  And a ticket "JIRA-456" with summary "Not so urgent ticket" is started at "2014-09-30 15:02:00"

  # 2014-10-01
  And a commit "#master2" with message "historic commit" is created at "2014-10-01 12:01:17"

  # 2014-10-02
  And the branch "feature" is checked out
  And a commit "#branch1" with message "first commit" is created at "2014-10-02 14:01:17"
  And developer prepares review known as "FR_123" for UAT "uat.fundingcircle.com" with apps
    | app_name | version  |
    | frontend | #branch1 |
  And at time "2014-10-02 15:12:45" adds link for review "FR_123" to comment for ticket "JIRA-123"

  # 2014-10-03
  And the branch "feature" is checked out
  And a commit "#branch2" with message "second commit" is created at "2014-10-03 14:04:19"
  And commit "#branch2" of "frontend" is deployed by "Alice" to server "uat.fundingcircle.com" at "2014-10-03 14:25:00"
  And developer prepares review known as "FR_456" for UAT "uat.example.com" with apps
    | app_name | version  |
    | frontend | #branch2 |
  And at time "2014-10-03 15:19:53" adds link for review "FR_456" to comment for ticket "JIRA-456"

  # 2014-10-04
  And ticket "JIRA-456" is approved by "bob@fundingcircle.com" at "2014-10-04 15:24:34"

  # 2014-10-05
  And the branch "master" is checked out
  And a commit "#master3" with message "sneaky commit" is created at "2014-10-05 11:01:02"
  And developer prepares review known as "FR_789" for UAT "uat.example.com" with apps
    | app_name | version  |
    | frontend | #master3 |
  And at time "2014-10-05 11:02:00" adds link for review "FR_789" to comment for ticket "JIRA-789"
  And ticket "JIRA-789" is approved by "jeff@fundingcircle.com" at "2014-10-05 11:03:45"
  And commit "#master3" of "frontend" is deployed by "Jeff" to production at "2014-10-05 11:54:20"

  # 2014-10-06
  And the branch "master" is checked out
  And the branch "feature" is merged with merge commit "#merge" at "2014-10-06 17:04:19"

  When I view the releases for "frontend"

  Then I should see the "pending" releases
    | version  | subject                        | feature reviews | review statuses     | review times                             | approved | committed to master at |
    | #merge   | Merged `feature` into `master` | FR_456          | approved            | 2014-10-04 15:24:34                      | yes      | 2014-10-06 17:04       |
    | #branch2 | second commit                  | FR_456          | approved            | 2014-10-04 15:24:34                      | yes      | 2014-10-06 17:04       |
    | #branch1 | first commit                   | FR_123, FR_456  | unapproved approved | 2014-10-06 17:04:19, 2014-10-04 15:24:34 | yes      | 2014-10-06 17:04       |

  And I should see the "deployed" releases
    | version      | subject                    | feature reviews | review statuses     | review times     | approved | committed to master at | last deployed at |
    | #master3     | sneaky commit              |                 |                     | 2014-10-05 11:01 | no       | 2014-10-05 11:01       | 2014-10-05 11:54 |
    | #master2     | historic commit            |                 |                     | 2014-10-01 12:01 | no       | 2014-10-01 12:01       |                  |
    | #master1     | initial commit             |                 |                     | 2014-09-29 09:18 | no       | 2014-09-29 09:18       | 2014-09-29 11:37 |
