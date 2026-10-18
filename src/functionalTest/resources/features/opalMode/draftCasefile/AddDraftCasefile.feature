@Opal @JIRA-STORY:PO-10287 @JIRA-EPIC:PO-6506 @PO10287
Feature: Create a submitted Draft Casefile

  Scenario: An authorised user creates and observes a submitted Draft Casefile
    Given I am testing as the "opal-test@dev.platform.hmcts.net" user
    And I prepare a valid uniquely marked Draft Casefile
    When I submit the Draft Casefile
    Then the submitted Draft Casefile response is returned
    And the stored Draft Casefile technical outcome is observable
