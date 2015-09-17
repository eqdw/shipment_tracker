Feature:
  Developer raises a pull request in github

@logged_in
Scenario: Opening a pull request
  Given an application called "frontend"
  And a commit "#master1" with message "master commit" is created at "00:01:00"
  And the branch "important-branch" is checked out
  And a commit "#branch1" with message "branch commit" is created at "00:02:00"
  And developer prepares review known as "Important-Review" for UAT "uat.example.com" with apps
    | app_name | version  |
    | frontend | #branch1 |
  And a ticket "JIRA-100" with summary "Important ticket" is started at "2014-09-29 15:02:00"
  And at time "00:03:00" adds link for review "Important-Review" to comment for ticket "JIRA-100"
  Then all pull requests for "#branch1" should be updated to "failure" status
  When ticket "JIRA-100" is approved by "alice@fundingcircle.com" at "00:04:00"
  Then all pull requests for "#branch1" should be updated to "success" status
