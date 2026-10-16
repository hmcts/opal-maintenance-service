@Opal @PO10630 @Ignore
Feature: Replace a rejected maintenance Draft Casefile
  # Opt in with @PO10630 using an approved synthetic fixture. Reset its lifecycle before each rerun.

  Scenario: Correct, resubmit and protect the saved version
    Given an approved synthetic rejected draft is available for replacement
    When I replace the draft using its current ETag
    Then the corrected draft is resubmitted with preserved history and a new ETag
    And reusing the original ETag is rejected without changing the draft

  Scenario: Reject unauthenticated replacement
    Given an approved synthetic draft is available for unauthenticated replacement
    When I replace the draft without authentication
    Then the replacement is unauthorized
