@logged_in
@wip
Feature: Viewing Releases
  As a deployer
  I want to view all releases for a given application
  So I know which versions are safe to deploy and which versions have already been deployed

Scenario: Viewing releases for an app
  Given an application called "frontend"
  And a ticket "JIRA-123" with summary "Urgent ticket" is started
  And a commit "#master1" with message "historic commit" is created at "13:01:17"
  And the branch "feature" is checked out
  And a commit "#branch1" with message "first commit" is created at "14:01:17"
  And a commit "#branch2" with message "second commit" is created at "15:04:19"
  And commit "#branch2" of "frontend" is deployed by "Alice" to server "uat.fundingcircle.com"
  And a developer prepares a review for UAT "uat.fundingcircle.com" with apps
    | app_name | version  |
    | frontend | #branch2 |
  And adds the link to a comment for ticket "JIRA-123"
  And ticket "JIRA-123" is approved by "bob@fundingcircle.com" at "15:24:34"
  And the branch "master" is checked out
  And a commit "#master2" with message "sneaky commit" is created at "13:31:17"
  And commit "#master2" of "frontend" is deployed by "Charlotte" to production at "15:54:20"
  And the branch "feature" is merged with merge commit "#merge" at "16:04:19"

  When I view the releases for "frontend"

  Then I should see the "pending" releases
    | version  | subject                            | issue audit          | approved |
    | #merge   | Merged `feature` into `master`     | Ready for Deployment | yes      |
    | #branch2 | second commit                      | Ready for Deployment | yes      |
    | #branch1 | first commit                       | Ready for Deployment | yes      |

  And I should see the "deployed" releases
    | version  | subject                            | issue audit          | approved | last deployed at |
    | #master2 | sneaky commit                      |                      | no       | 15:54            |
    | #master1 | historic commit                    |                      | no       |                  |
