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
