@Opal @JIRA-LABEL:reference-data
Feature: Results Reference Data

  # Uses the normal all-environment seed: three active Order Terms and no inactive Order Terms.
  # Requests are read-only; data is not changed or shared as mutable scenario state.
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
  Scenario: Return an empty response when no inactive Order Terms exist
    Given I am testing as the "opal-test@dev.platform.hmcts.net" user
    When I request inactive Results available as Order Terms
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

  # Uses MLUMP from normal reference data; ZZZZZZ must remain unallocated.
  # Inactive, unfamiliar, SQL-null and encoded-empty states are integration coverage.
  @JIRA-STORY:PO-10301 @JIRA-EPIC:PO-6506
  Scenario: Retrieve selected active Order Term Result details
    Given I am testing as the "opal-test@dev.platform.hmcts.net" user
    And I have selected the Result with identifier "MLUMP"
    When I request the selected Result details
    Then the selected Result identity and parameter metadata are returned
    And the metadata describes the expected amount input

  @JIRA-STORY:PO-10301 @JIRA-EPIC:PO-6506
  Scenario: A selected Result does not exist
    Given I am testing as the "opal-test@dev.platform.hmcts.net" user
    And I have selected the Result with identifier "ZZZZZZ"
    When I request the selected Result details
    Then a correlated Result not-found response is returned without Result data

  @JIRA-STORY:PO-10301 @JIRA-EPIC:PO-6506
  Scenario: Result details require authentication
    Given I have selected the Result with identifier "MLUMP"
    When I request the selected Result details without authentication
    Then Result details require authentication without exposing Result data
