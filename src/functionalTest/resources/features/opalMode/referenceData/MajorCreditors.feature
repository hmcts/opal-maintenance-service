@Opal @JIRA-LABEL:reference-data
Feature: Major Creditor reference data

  @JIRA-STORY:PO-10294 @JIRA-EPIC:PO-6506
  Scenario: Retrieve active Central Authorities
    Given I am testing as the "opal-test@dev.platform.hmcts.net" user
    When I request active Central Authorities for the seeded business unit
    Then the Central Authority details are available for casefile selection

  @JIRA-STORY:PO-10294 @JIRA-EPIC:PO-6506
  Scenario: Reject a malformed Central Authority filter
    Given I am testing as the "opal-test@dev.platform.hmcts.net" user
    When I request Central Authorities with a malformed authority filter
    Then a correlated Central Authority validation rejection is returned

  @JIRA-STORY:PO-10294 @JIRA-EPIC:PO-6506
  Scenario: Central Authorities require authentication
    When I request Central Authorities without authentication
    Then authentication is required without exposing Central Authority data

  @JIRA-STORY:PO-10297 @JIRA-EPIC:PO-6506 @PO10297Active
  Scenario: Retrieve active Major Creditors
    Given I am testing as the "opal-test@dev.platform.hmcts.net" user
    And isolated Major Creditor reference data is available
    When I request active non-Central Authority Major Creditors
    Then the Major Creditors required for creditor selection are returned

  @JIRA-STORY:PO-10297 @JIRA-EPIC:PO-6506 @PO10297Malformed
  Scenario: Reject a malformed Major Creditor filter
    Given I am testing as the "opal-test@dev.platform.hmcts.net" user
    When I request Major Creditors with a malformed active filter
    Then the Major Creditor validation response is correlated

  @JIRA-STORY:PO-10297 @JIRA-EPIC:PO-6506 @PO10297Authentication
  Scenario: Major Creditors require authentication
    When I request Major Creditors without authentication
    Then Major Creditor reference data is not disclosed
