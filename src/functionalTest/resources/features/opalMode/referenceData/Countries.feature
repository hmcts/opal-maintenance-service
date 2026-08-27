@Opal @JIRA-LABEL:reference-data
Feature: Countries Reference Data

  @JIRA-STORY:PO-10290 @JIRA-EPIC:PO-6506 @PO10290Active
  Scenario: Retrieve active Countries
    Given I am testing as the "opal-test@dev.platform.hmcts.net" user
    When I request all Countries
    And I request active Countries
    And I request inactive Countries
    Then the Country active filter partitions the available Countries

  @JIRA-STORY:PO-10290 @JIRA-EPIC:PO-6506 @PO10290Malformed
  Scenario: Reject a malformed Country filter
    Given I am testing as the "opal-test@dev.platform.hmcts.net" user
    When I request Countries with a malformed active filter
    Then the Country validation Problem Details response is returned
