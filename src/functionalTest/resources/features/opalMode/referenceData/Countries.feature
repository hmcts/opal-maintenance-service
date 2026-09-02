@Opal @JIRA-LABEL:reference-data
Feature: Countries Reference Data

  # Requires the target environment to contain one active GBR / United Kingdom record
  # and at least one other active Country.
  @JIRA-STORY:PO-10290 @JIRA-EPIC:PO-6506 @PO10290Active
  Scenario: Retrieve Active Countries in display order
    Given I am testing as the "opal-test@dev.platform.hmcts.net" user
    When I request active Countries
    Then active Countries are returned in display order for casefile address selection

  @JIRA-STORY:PO-10290 @JIRA-EPIC:PO-6506 @PO10290Malformed
  Scenario: Reject a malformed Country filter
    Given I am testing as the "opal-test@dev.platform.hmcts.net" user
    When I request Countries with a malformed active filter
    Then the Country validation Problem Details response is returned

  @JIRA-STORY:PO-10290 @JIRA-EPIC:PO-6506 @PO10290Authentication
  Scenario: Countries require authentication
    When I request Countries without authentication
    Then the Country unauthorized Problem Details response is returned
