# Shipment Tracker
[![Circle CI](https://img.shields.io/circleci/project/FundingCircle/shipment_tracker/master.svg)](https://circleci.com/gh/FundingCircle/shipment_tracker)
[![Code Climate](https://img.shields.io/codeclimate/github/FundingCircle/shipment_tracker.svg)](https://codeclimate.com/github/FundingCircle/shipment_tracker)
[![Test Coverage](https://img.shields.io/codeclimate/coverage/github/FundingCircle/shipment_tracker.svg)](https://codeclimate.com/github/FundingCircle/shipment_tracker)

[![](http://i.imgur.com/VkjlJmj.jpg)](https://www.flickr.com/photos/britishlibrary/11237769263/)

Tracks shipment of software versions for audit purposes.

The app has various "audit endpoints" to receive events,
such as deploys, builds, ticket creations, etc.

All received events are stored in the DB and are never modified.
[Event sourcing] is used to replay each event allowing us to reconstruct the state
of the system at any point in time.

## Getting Started

Install the Ruby version specified in `.ruby-version`.

Install the Gems.

```
bundle install
```

Setup database and environment.

```
cp .env.development.example .env.development
cp config/database.yml.example config/database.yml
bundle exec rake db:setup
```

Set up Git hooks, for running tests and linters before pushing to master.

```
bundle exec rake git:setup_hooks
```

Pull sample data from a remote server (on Heroku - relies on the heroku toolbelt and a suitable git remote):

```
bundle exec rake heroku:pull
```


### Enabling access to repositories via SSH

Ensure that `libssh2` is installed and the `rugged` gem is reinstalled. On OSX:

```
brew install libssh2
gem pristine rugged
```

When booting server, set Environment variables `SSH_USER`, `SSH_PUBLIC_KEY` and `SSH_PRIVATE_KEY`:

```
SSH_USER=git \
SSH_PUBLIC_KEY='ssh-rsa AAAXYZ' \
SSH_PRIVATE_KEY='-----BEGIN RSA PRIVATE KEY-----
abcdefghijklmnopqrstuvwxyz
-----END RSA PRIVATE KEY-----' \
rails s -p 1201
```

Note that port 1201 is only needed in development; it's the expected port by auth0 (the service we use for authentication).

You can also use Foreman to start the server and use settings from Heroku:

```
bin/boot_with_heroku_settings
```

### Running event snapshots

In order to return results from recent events, Shipment Tracker needs to continuously record snapshots.
There is a rake task `jobs:update_events_loop` which continuously updates the event cache.
We suggest that you have this running in the background (e.g. using Supervisor or a Heroku worker).

There is also a rake task `jobs:update_events` for running the snapshotting manually,
for example, after you clear the event snapshots with the `db:clear_snapshots` rake task.

*Warning:* This recurring task should only run on **one** server.

### Enabling periodic git fetching

It's important to keep the Shipment Tracker git cache reasonably up-to-date to avoid request timeouts.

Please make sure the following command runs every few minutes:

```
bundle exec rake jobs:update_git
```

*Warning:* This recurring task should run on **every** server that your application is running on.

### Enable GitHub Webhooks

[Configure GitHub webhooks][webhooks] at an organization-wide level or per repository for **push** and **pull request** notifications.

Shipment Tracker uses push notifications to update repositories that it keeps track of. It uses pull request notifications to show a status check in pull requests.

To configure the webhook for a repository, first go into the API Tokens tab of Shipment Tracker and find (or create) a Github Notifications token. Next, in Github, go into the repository settings and add a new webhook. The "Payload URL" should be set to the Github Notifications URL from Shipment Tracker, the "Content type" should be JSON, and Github should send *All* events for this repository. Add the webhook, and all new Github Pull Requests should now show the Shipment Tracker status.

You'll also need a [GitHub Access Token][access tokens] for authentication with the GitHub API. It'll only need the `repo:status` scope enabled. Set the token as the `GITHUB_REPO_STATUS_ACCESS_TOKEN` environment variable when booting the application (use `.env.development` during development).

### Maintenance Mode

When recreating snapshots, you may want to put the application in maintenance mode.
This is to disable GitHub status notifications and to tell the user that some data may appear out of date.

To enable maintenance mode, set an environment variable called `DATA_MAINTENANCE=true`.
The application will require a reboot before taking effect.

## License

Copyright © 2015 Funding Circle Ltd.

Distributed under the BSD 3-Clause License.

[Event sourcing]: http://www.infoq.com/presentations/Events-Are-Not-Just-for-Notifications
[webhooks]: https://help.github.com/articles/about-webhooks/
[access tokens]: https://help.github.com/articles/creating-an-access-token-for-command-line-use/
