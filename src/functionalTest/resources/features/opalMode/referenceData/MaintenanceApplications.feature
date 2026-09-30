@Opal @JIRA-LABEL:reference-data
Feature: Maintenance Applications Reference Data

  # Requires the target environment to contain the approved all-environment baseline:
  # active Create Casefile Maintenance Applications, including AP00001 / Application to Appeal,
  # and no inactive Create Casefile Maintenance Applications.
  @JIRA-STORY:PO-10288 @JIRA-EPIC:PO-6506 @PO10288Active
  Scenario: Retrieve active Create Casefile Maintenance Applications
    Given I am testing as the "opal-test@dev.platform.hmcts.net" user
    When I request active Maintenance Applications for Create Casefile
    Then active Maintenance Applications are returned for Order Details

  @JIRA-STORY:PO-10288 @JIRA-EPIC:PO-6506 @PO10288Empty
  Scenario: Return an empty response when no inactive Create Casefile applications exist
    Given I am testing as the "opal-test@dev.platform.hmcts.net" user
    When I request inactive Maintenance Applications for Create Casefile
    Then an empty Maintenance Applications response is returned

  @JIRA-STORY:PO-10288 @JIRA-EPIC:PO-6506 @PO10288Malformed
  Scenario: Reject a malformed Maintenance Applications active filter
    Given I am testing as the "opal-test@dev.platform.hmcts.net" user
    When I request Maintenance Applications with a malformed active filter
    Then the Maintenance Applications validation Problem Details response is returned

  @JIRA-STORY:PO-10288 @JIRA-EPIC:PO-6506 @PO10288Authentication
  Scenario: Maintenance Applications require authentication
    When I request Maintenance Applications without authentication
    Then the Maintenance Applications unauthorized Problem Details response is returned
