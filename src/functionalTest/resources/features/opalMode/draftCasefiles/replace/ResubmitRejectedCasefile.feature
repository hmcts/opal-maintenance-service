@Opal @PO10622 @JIRA-STORY:PO-10622
Feature: Resubmit a complete rejected Draft Casefile

  Background:
    Given an owned rejected casefile with complete original content

  Scenario: The original inputter resubmits a complete correction
    When the original inputter resubmits its complete correction
    Then the corrected casefile is persisted with the authenticated latest submitter and no publication

  Scenario: Another authorised inputter takes ownership and cannot check their own work
    When another authorised inputter resubmits its complete correction
    Then the corrected casefile is persisted with the authenticated latest submitter and no publication
    And the latest submitter cannot check its own resubmitted work

  Scenario: An unknown application preserves the rejected casefile
    When the original inputter attempts a correction with an unknown application
    Then a safe validation problem preserves the complete rejected casefile and no publication

  Scenario: A caller without owning Business Unit create permission cannot resubmit
    When a caller without create permission attempts the complete correction
    Then a safe denied problem preserves the complete rejected casefile and no publication

  Scenario: A supplied different Business Unit cannot rewrite ownership
    When the original inputter attempts the complete correction in a different Business Unit
    Then a safe ownership conflict preserves the complete rejected casefile and no publication
