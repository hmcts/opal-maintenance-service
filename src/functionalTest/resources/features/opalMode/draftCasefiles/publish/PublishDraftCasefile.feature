@Opal @PO10621 @JIRA-STORY:PO-10621
Feature: Publish an approved Draft Casefile

  Scenario Outline: Publish all generated account identities
    Given a new publication casefile with "<minor creditors>" is independently approved
    When the publication consumer publishes the owned casefile
    Then all publication identities and approval history are available on a stable read

    Examples:
      | minor creditors |
      | none            |
      | two             |

  Scenario: Retain approval details after terminal publication failure
    Given a new unpublishable publication casefile is independently approved
    When the publication consumer records terminal failure for the owned casefile
    Then failed publication preserves its approval snapshot and history on a stable read
