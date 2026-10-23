@Opal @PO10618 @JIRA-STORY:PO-10618
Feature: Retrieve a Draft Casefile

  Scenario: Retrieve a complete authorised Draft Casefile
    Given a new scenario-owned complete Draft Casefile is submitted
    When the owning user retrieves the scenario Draft Casefile
    Then the complete submitted Draft Casefile is returned

  Scenario: Retrieve all generated account identities after publication
    Given a new scenario-owned complete Draft Casefile is submitted
    And a different authorised checker approves the scenario Draft Casefile
    When the owner retrieves the scenario Draft Casefile after successful publication
    Then all published account identities and the approval history are returned

  Scenario: Retrieve a failed publication without invented account identities
    Given a new scenario-owned unpublishable Draft Casefile is submitted
    And a different authorised checker approves the scenario Draft Casefile
    When the owner retrieves the scenario Draft Casefile after failed publication
    Then the failed publication retains validation and approval history without account identities

  Scenario: Protect a missing Draft Casefile
    Given a new scenario-owned complete Draft Casefile is submitted
    And the owner removes the scenario Draft Casefile
    When the owning user retrieves the scenario Draft Casefile
    Then a safe missing Draft Casefile response is returned

  Scenario: Protect a Draft Casefile outside the reader's authorised Business Units
    Given a new scenario-owned complete Draft Casefile is submitted
    When a user without either owning Business Unit permission retrieves the scenario Draft Casefile
    Then a safe forbidden Draft Casefile response is returned
