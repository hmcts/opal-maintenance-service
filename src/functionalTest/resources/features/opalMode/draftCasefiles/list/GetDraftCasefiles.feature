@Opal @PO10619 @JIRA-STORY:PO-10619
Feature: List Draft Casefiles owned by an authorised Business Unit

  Scenario: Filter summaries by owning unit submitter lifecycle and UTC date
    Given owned matching and nonmatching Draft Casefiles for list filters
    When the role user lists Draft Casefiles with the scenario filters
    Then every list summary satisfies all filters and only the matching owned drafts appear

  Scenario: Count rejected work without personal summaries
    Given an owned rejected Draft Casefile for list counts
    When the role user lists Draft Casefiles with the scenario filters
    Then the matching owned draft is listed and counts restriction returns the same matching count only

  Scenario: Count failed publication work without personal summaries
    Given an independently owned failed publication for list verification
    When the role user lists Draft Casefiles with the scenario filters
    Then the matching owned draft is listed and counts restriction returns the same matching count only

  Scenario: Checker excludes their own submissions from reviewable work
    Given owned submissions by the inputter and the reviewing checker
    When the role user lists Draft Casefiles with the scenario filters
    Then the checker sees the other user's reviewable draft and excludes their own

  Scenario: Authorised contradictory filters return an empty collection
    Given an owned submission for a contradictory authorised list filter
    When the role user lists Draft Casefiles with the scenario filters
    Then the authorised list has zero count and an empty summaries array

  Scenario: Published summary preserves identities validation and approval history
    Given an independently owned published casefile with two minor creditors for list verification
    When the role user lists Draft Casefiles with the scenario filters
    Then the published summary matches full retrieval identities validation and unchanged approval history

  Scenario: Failed summary preserves null identities validation and approval history
    Given an independently owned failed publication for list verification
    When the role user lists Draft Casefiles with the scenario filters
    Then the failed summary matches full retrieval null identities validation and unchanged approval history
