@Opal @PO10617 @JIRA-STORY:PO-10617
Feature: Record independent checker decisions

  Scenario Outline: Record an independent checker decision from a reviewable draft
    Given an owned complete <source> Draft Casefile is ready for checking
    When the independent checker records <decision> with the current version
    Then the decision is persisted with server-owned history and the expected producer evidence

    Examples:
      | source      | decision |
      | SUBMITTED   | Approve  |
      | SUBMITTED   | Reject   |
      | SUBMITTED   | Delete   |
      | RESUBMITTED | Approve  |
      | RESUBMITTED | Reject   |
      | RESUBMITTED | Delete   |

  Scenario: Refuse approval of the checker's own submission
    Given an owned submission by a user with both create and check permissions
    When that same checker attempts approval
    Then a safe forbidden response preserves the draft and complete zero producer evidence

  Scenario: Refuse approval without owning Business Unit permission
    Given an owned complete SUBMITTED Draft Casefile is ready for checking
    When a caller without owning Business Unit permission attempts approval
    Then a safe forbidden response preserves the draft and complete zero producer evidence

  Scenario: Refuse approval with an obsolete original version
    Given an owned RESUBMITTED Draft Casefile with its obsolete original version
    When the independent checker approves using that obsolete version
    Then a safe version conflict preserves the draft and complete zero producer evidence

  Scenario: Refuse approval of a currently rejected draft
    Given an owned REJECTED Draft Casefile with a current version
    When the independent checker attempts approval of that rejected draft
    Then a safe lifecycle conflict preserves the draft and complete zero producer evidence
