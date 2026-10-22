@Opal @JIRA-STORY:PO-10287 @JIRA-EPIC:PO-6506 @PO10287
Feature: Draft Casefile creation failures

  Scenario Outline: Invalid Draft Casefile references are rejected
    Given I am testing as the "opal-test@dev.platform.hmcts.net" user
    And I prepare a uniquely marked Draft Casefile with an <reference>
    When I submit the Draft Casefile
    Then the invalid <reference> Draft Casefile response is returned

    Examples:
      | reference           |
      | unknown application |
      | inactive country    |
      | historical country  |
