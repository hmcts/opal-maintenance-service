@Opal @JIRA-LABEL:reference-data
Feature: Results Reference Data

  # Data and cache preconditions are documented in docs/TESTING.md.
  # Active and Empty require their respective controlled target states.
  @JIRA-STORY:PO-10298 @JIRA-EPIC:PO-6506 @PO10298Active
  Scenario: Retrieve active Order Term Results
    Given I am testing as the "opal-test@dev.platform.hmcts.net" user
    When I request active Results available as Order Terms
    Then the returned Order Term Results are
      | result_id | result_title                    |
      | MLUMP     | Lump sum order                  |
      | MCHILD    | Maintenance Order for child(ren) |
      | MAT       | Matrimonial Order for Adult     |

  @JIRA-STORY:PO-10298 @JIRA-EPIC:PO-6506 @PO10298Empty
  Scenario: No active Order Term Results
    Given I am testing as the "opal-test@dev.platform.hmcts.net" user
    When I request active Results available as Order Terms from the empty target
    Then an empty Order Term Results response is returned

  @JIRA-STORY:PO-10298 @JIRA-EPIC:PO-6506 @PO10298Malformed
  Scenario: Reject a malformed Order Term Result filter
    Given I am testing as the "opal-test@dev.platform.hmcts.net" user
    When I request Order Term Results with a malformed order_term filter
    Then the Order Term Results validation Problem Details response is returned

  @JIRA-STORY:PO-10298 @JIRA-EPIC:PO-6506 @PO10298Authentication
  Scenario: Order Term Results require authentication
    When I request active Order Term Results without authentication
    Then the Order Term Results unauthorized Problem Details response is returned

  # Requires the scenario-owned PO-10301 fixtures in an isolated functional environment.
  # Prepare and validate the data before starting the service with a fresh cache.
  # HTTP scenarios do not create, alter or remove reference data.

  @JIRA-STORY:PO-10301 @JIRA-EPIC:PO-6506
  Scenario: Retrieve selected active Order Term Result details
    Given I am testing as the "opal-test@dev.platform.hmcts.net" user
    And I have selected the Result with identifier "Q301A1"
    When I request the selected Result details
    Then the selected Result identity, title and stored metadata are returned unchanged
    And the metadata describes the expected amount input

  @JIRA-STORY:PO-10301 @JIRA-EPIC:PO-6506
  Scenario: Retrieve an inactive Result by its identifier
    Given I am testing as the "opal-test@dev.platform.hmcts.net" user
    And I have selected the Result with identifier "Q301I1"
    When I request the selected Result details
    Then the selected Result identity, title and stored metadata are returned unchanged

  @JIRA-STORY:PO-10301 @JIRA-EPIC:PO-6506
  Scenario: A selected Result does not exist
    Given I am testing as the "opal-test@dev.platform.hmcts.net" user
    And I have selected the Result with identifier "Q301X1"
    When I request the selected Result details
    Then a correlated Result not-found response is returned without Result data

  @JIRA-STORY:PO-10301 @JIRA-EPIC:PO-6506
  Scenario: Return stored metadata with an unfamiliar parameter type unchanged
    Given I am testing as the "opal-test@dev.platform.hmcts.net" user
    And I have selected the Result with identifier "Q301U1"
    When I request the selected Result details
    Then the selected Result identity, title and stored metadata are returned unchanged

  @JIRA-STORY:PO-10301 @JIRA-EPIC:PO-6506
  Scenario: A selected Result has no stored parameter metadata
    Given I am testing as the "opal-test@dev.platform.hmcts.net" user
    And I have selected the Result with identifier "Q301N1"
    When I request the selected Result details
    Then the selected Result identity, title and stored metadata are returned unchanged

  @JIRA-STORY:PO-10301 @JIRA-EPIC:PO-6506
  Scenario: A selected Result has an empty parameter list
    Given I am testing as the "opal-test@dev.platform.hmcts.net" user
    And I have selected the Result with identifier "Q301E1"
    When I request the selected Result details
    Then the selected Result identity, title and stored metadata are returned unchanged

  @JIRA-STORY:PO-10301 @JIRA-EPIC:PO-6506
  Scenario: Result details require authentication
    Given I have selected the Result with identifier "Q301T1"
    When I request the selected Result details without authentication
    Then Result details require authentication without exposing Result data
