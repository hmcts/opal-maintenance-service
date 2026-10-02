@Opal @JIRA-LABEL:reference-data @JIRA-STORY:PO-10294 @JIRA-EPIC:PO-6506
Feature: Retrieve Central Authorities

  Scenario: Retrieve active Central Authorities
    Given I am testing as the "opal-test@dev.platform.hmcts.net" user
    And this scenario owns active and excluded Central Authority records
    When I request active Central Authorities for this scenario's business unit
    Then the Central Authority details are available for casefile selection

  Scenario: Reject a malformed Central Authority filter
    Given I am testing as the "opal-test@dev.platform.hmcts.net" user
    When I request Central Authorities with a malformed authority filter
    Then a correlated Central Authority validation rejection is returned

  Scenario: Central Authorities require authentication
    When I request Central Authorities without authentication
    Then authentication is required without exposing Central Authority data
