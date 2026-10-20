@Opal @JIRA-LABEL:user-state @JIRA-STORY:PO-10302 @JIRA-EPIC:PO-6506
Feature: RM User State for the Draft Casefile journey

  @PO10302Granted
  Scenario: Retrieve Draft Casefile permission in User State
    Given I select the "granted" RM User State assignment
    When I request my RM User State
    Then my Maintenance Business Unit includes the Draft Casefile permission

  @PO10302Denied
  Scenario: Draft Casefile permission is not granted implicitly
    Given I select the "denied" RM User State assignment
    When I request my RM User State
    Then my Maintenance Business Unit does not grant the Draft Casefile permission

  @PO10302Authentication
  Scenario: User State requires authentication
    When I request RM User State without authentication
    Then my Business Unit assignments and permissions are not disclosed
