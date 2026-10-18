@Opal @JIRA-STORY:PO-10287 @JIRA-EPIC:PO-6506 @PO10287
Feature: Draft Casefile creation failures

  Scenario Outline: Invalid Draft Casefile references are rejected without persistence
    Given I am testing as the "opal-test@dev.platform.hmcts.net" user
    And I prepare a uniquely marked Draft Casefile with an <reference>
    When I submit the Draft Casefile
    Then the invalid <reference> Draft Casefile response is returned
    And no Draft Casefile exists for the scenario marker

    Examples:
      | reference           |
      | unknown application |
      | inactive country    |
      | historical country  |

  Scenario: A post-save failure rolls back the complete Draft Casefile
    Given I am testing as the "opal-test@dev.platform.hmcts.net" user
    And I prepare a valid uniquely marked Draft Casefile
    When I submit the Draft Casefile with a post-save testing failure
    Then the correlated Draft Casefile server failure is returned
    And no Draft Casefile exists for the scenario marker
