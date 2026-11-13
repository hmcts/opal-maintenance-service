@Smoke
Feature: Maintenance service health

  @JiraMetadataExempt
  Scenario: The health endpoint reports that the Maintenance service is up
    When I request the Maintenance service health status
    Then the Maintenance service reports as up
