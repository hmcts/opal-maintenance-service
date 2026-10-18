@Opal @JIRA-STORY:PO-10287 @JIRA-EPIC:PO-6506 @PO10287
Feature: Draft Casefile creation authorisation

  Scenario: A user without Business Unit permission cannot create a Draft Casefile
    Given I am testing as the "opal-test-2@dev.platform.hmcts.net" user
    And I prepare a valid uniquely marked Draft Casefile
    When I submit the Draft Casefile
    Then the Draft Casefile permission failure is returned
    And I am testing as the "opal-test@dev.platform.hmcts.net" user
    And no Draft Casefile exists for the scenario marker
