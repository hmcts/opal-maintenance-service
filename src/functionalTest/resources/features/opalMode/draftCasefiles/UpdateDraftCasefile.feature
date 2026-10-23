@Opal @PO10631 @Ignore
Feature: Check a submitted maintenance Draft Casefile
  # Opt in with @PO10631 using separate synthetic fixtures and an available publication queue.
  # Reset the fixtures before a rerun. The publication consumer must be stopped for pending-state assertions.

  Scenario Outline: Record an independent checker decision
    Given an approved synthetic submitted draft is available for "<target>"
    When the checker records the decision with the current ETag
    Then the draft records "<history>" with preserved content and a new ETag

    Examples:
      | target             | history  |
      | PUBLISHING_PENDING | Approved |
      | REJECTED           | Rejected |
      | DELETED            | Deleted  |

  Scenario: Refuse a checker deciding their own submission
    Given an approved synthetic draft was submitted by the checker
    When the checker records the decision with the current ETag
    Then the self-check is forbidden without changing the draft
