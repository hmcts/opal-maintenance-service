# Build alerts

GitHub Actions reports completed Jenkins master builds to the Opal Teams Builds
channel. The Alerts channel receives a first failed result, a new-code build
that remains failed, and recovery. Set the repository variable
`OPAL_MASTER_ALERT_REPORT_ALL_BUILDS=true` to send every completed master result
to Alerts as well; a missing or invalid value behaves as `false`.

The nightly Jenkins job sends its final result through a separate GitHub
`repository_dispatch` event. Its Action reports every result to the Opal Nightly
Builds channel. Nightly failures do not alter the regular master commit status.

The Actions require these repository secrets, each containing the corresponding
Teams Workflows webhook URL:

- `OPAL_MASTER_ALERT_TEAMS_WEBHOOK`
- `OPAL_MASTER_BUILDS_TEAMS_WEBHOOK`
- `OPAL_NIGHTLY_BUILDS_TEAMS_WEBHOOK`

The nightly dispatch uses the GitHub credential already established by the
Jenkins pipeline. If checkout or credential setup fails before that point, the
Jenkinsfile logs that the result could not be dispatched. A webhook accepting a
card does not prove it appeared in Teams; check the Teams workflow run when a
card is missing.
