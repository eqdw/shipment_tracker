@logged_in
Feature: Viewing Releases
  As a deployer
  I want to view all releases for a given application
  So I know which versions are safe to deploy and which versions have already been deployed

Scenario: Viewing releases for an app
  # 2014-09-28 - application creation
  Given an application called "frontend"
  And a commit "#master1" with message "initial commit" is created at "2014-09-28 09:18:57"
  And commit "#master1" of "frontend" is deployed by "Fred" to production at "2014-09-28 11:37:13"

  # 2014-09-29 - ticket creation
  And a ticket "JIRA-ONE" with summary "Ticket ONE" is started at "2014-09-29 09:13:00"
  And a ticket "JIRA-789" with summary "Old ticket" is started at "2014-09-29 13:01:17"
  And a ticket "JIRA-123" with summary "Urgent ticket" is started at "2014-09-29 14:31:46"
  And a ticket "JIRA-456" with summary "Not so urgent ticket" is started at "2014-09-29 15:02:00"

  # 2014-09-30
  And a commit "#master2" with message "historic commit" is created at "2014-09-30 12:01:17"

  # 2014-10-01 - reverting approval for release that has been merged and deployed
  And the branch "feature1" is checked out
  And a commit "#feat1_a" with message "feat1 first commit" is created at "2014-10-01 13:12:37"
  And developer prepares review known as "FR_ONE" for UAT "uat.fundingcircle.com" with apps
    | app_name | version  |
    | frontend | #feat1_a |
  And at time "2014-10-01 14:52:45" adds link for review "FR_ONE" to comment for ticket "JIRA-ONE"
  And ticket "JIRA-ONE" is approved by "bob@fundingcircle.com" at "2014-10-01 15:20:34"
  And the branch "master" is checked out
  And the branch "feature1" is merged with merge commit "#merge1" at "2014-10-01 16:14:39"
  And commit "#merge1" of "frontend" is deployed by "Jeff" to production at "2014-10-01 17:34:20"
  And ticket "JIRA-ONE" is moved from approved to unapproved by "bob@fundingcircle.com" at "2014-10-01 18:15:28"

  # 2014-10-02
  And the branch "feature2" is checked out
  And a commit "#feat2_a" with message "feat2 first commit" is created at "2014-10-02 14:01:17"
  And developer prepares review known as "FR_123" for UAT "uat.fundingcircle.com" with apps
    | app_name | version  |
    | frontend | #feat2_a |
  And at time "2014-10-02 15:12:45" adds link for review "FR_123" to comment for ticket "JIRA-123"

  # 2014-10-03
  And the branch "feature2" is checked out
  And a commit "#feat2_b" with message "feat2 second commit" is created at "2014-10-03 14:04:19"
  And commit "#feat2_b" of "frontend" is deployed by "Alice" to server "uat.fundingcircle.com" at "2014-10-03 14:25:00"
  And developer prepares review known as "FR_123b" for UAT "uat.fundingcircle.com" with apps
    | app_name | version  |
    | frontend | #feat2_b |
  And at time "2014-10-03 15:12:45" adds link for review "FR_123b" to comment for ticket "JIRA-123"
  And developer prepares review known as "FR_456" for UAT "uat.example.com" with apps
    | app_name | version  |
    | frontend | #feat2_b |
  And at time "2014-10-03 15:19:53" adds link for review "FR_456" to comment for ticket "JIRA-456"

  # 2014-10-04
  And ticket "JIRA-456" is approved by "bob@fundingcircle.com" at "2014-10-04 15:24:34"

  # 2014-10-05 - approved after commit to master and deploy
  # allow developers to gain approval retrospectively
  And the branch "master" is checked out
  And a commit "#master3" with message "sneaky commit" is created at "2014-10-05 11:01:02"
  And developer prepares review known as "FR_789" for UAT "uat.example.com" with apps
    | app_name | version  |
    | frontend | #master3 |
  And at time "2014-10-05 11:02:00" adds link for review "FR_789" to comment for ticket "JIRA-789"
  And commit "#master3" of "frontend" is deployed by "Jeff" to production at "2014-10-05 11:54:20"
  And ticket "JIRA-789" is approved by "jeff@fundingcircle.com" at "2014-10-05 11:03:45"

  # 2014-10-06
  And the branch "master" is checked out
  And the branch "feature2" is merged with merge commit "#merge2" at "2014-10-06 17:04:19"

  When I view the releases for "frontend"

  Then I should see the "pending" releases
    | version                            | subject                    | feature reviews | review statuses       | review times          | approved |
    | [#merge2](https://github.com/...)  | Merge feature2 into master | FR_123b, FR_456 | Not approved Approved | , 2014-10-04 15:24:34 | yes      |

  And I should see the "deployed" releases
    | version                            | subject                    | feature reviews | review statuses       | review times          | approved | last deployed at |
    | [#master3](https://github.com/...) | sneaky commit              | FR_789          | Approved              | 2014-10-05 11:03:45   | yes      | 2014-10-05 11:54 |
    | [#merge1](https://github.com/...)  | Merge feature1 into master | FR_ONE          | Not approved          |                       | no       | 2014-10-01 17:34 |
    | [#master2](https://github.com/...) | historic commit            |                 |                       |                       | no       |                  |
    | [#master1](https://github.com/...) | initial commit             |                 |                       |                       | no       | 2014-09-28 11:37 |
