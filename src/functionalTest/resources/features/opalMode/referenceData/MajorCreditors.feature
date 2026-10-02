@Opal @JIRA-LABEL:reference-data
Feature: Major Creditor reference data

  @JIRA-STORY:PO-10294 @JIRA-EPIC:PO-6506
  Scenario: Retrieve active seeded Central Authorities
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

  # PO-10297 positive retrieval coverage is blocked by the current seed data.
  # Business unit 44 contains active Central Authorities only; there are no
  # seeded active non-Central Authority creditors or inactive comparison rows.
  # The empty-result scenario below does not fulfil the positive retrieval AC.
  # Add that scenario when approved non-Central Authority reference data exists.

  @JIRA-STORY:PO-10297 @JIRA-EPIC:PO-6506
  Scenario: No non-Central Authority creditors match the current seed
    Given I am testing as the "opal-test@dev.platform.hmcts.net" user
    When I request active non-Central Authority Major Creditors
    Then no non-Central Authority Major Creditors are returned for the seeded business unit

  @JIRA-STORY:PO-10297 @JIRA-EPIC:PO-6506
  Scenario: Reject a malformed Major Creditor active filter
    Given I am testing as the "opal-test@dev.platform.hmcts.net" user
    When I request Major Creditors with a malformed active filter
    Then the Major Creditor validation response is correlated

  @JIRA-STORY:PO-10297 @JIRA-EPIC:PO-6506
  Scenario: Major Creditors require authentication
    When I request Major Creditors without authentication
    Then Major Creditor reference data is not disclosed
