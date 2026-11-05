package uk.gov.hmcts.opal.scripts;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.concurrent.TimeUnit;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class TestJiraAnnotationCheckerTest {

    private static final String VALID_INTEGRATION_TEST = """
        import org.junit.jupiter.api.Test;
        import uk.hmcts.zephyr.automation.junit5.annotations.JiraEpic;
        import uk.hmcts.zephyr.automation.junit5.annotations.JiraStory;

        class ExampleIntegrationTest {
            @Test
            @JiraStory("PO-10251")
            @JiraEpic("PO-6506")
            void example() {}
        }
        """;
    private static final String VALID_FEATURE = """
        @JIRA-STORY:PO-10290 @JIRA-EPIC:PO-6506
        Feature: Example
          Scenario: A supported journey
            Given a supported precondition
        """;

    @TempDir
    private Path temporaryDirectory;

    @Test
    void acceptsInheritedFunctionalTagsAndIgnoresExcludedExamples() throws Exception {
        CheckerResult result = runChecker(VALID_INTEGRATION_TEST, """
            @JIRA-STORY:PO-10290 @JIRA-EPIC:PO-6506
            Feature: Example
              Scenario: A supported journey
                Given a supported precondition

              @JIRA-STORY:PO-10251
              Scenario Outline: A parameterised journey
                Given value <value>

                Examples: Included
                  | value |
                  | one   |
                  | two   |

                @Ignore
                Examples: Excluded
                  | value |
                  | three |
            """);

        assertEquals(0, result.exitCode(), result.output());
        assertTrue(result.output().contains("1 runnable integration test method(s)"), result.output());
        assertTrue(result.output().contains("2 runnable functional test case(s)"), result.output());
    }

    @Test
    void rejectsAnIntegrationMethodWithoutAStoryAndWithConflictingEpics() throws Exception {
        CheckerResult result = runChecker("""
            class ExampleIntegrationTest {
                @Test
                @JiraEpic("PO-6506")
                @JiraEpic("PO-10817")
                void example() {}
            }
            """, VALID_FEATURE);

        assertEquals(1, result.exitCode(), result.output());
        assertTrue(result.output().contains("missing @JiraStory annotation"), result.output());
        assertTrue(result.output().contains("has 2 @JiraEpic annotations"), result.output());
    }

    @Test
    void rejectsFunctionalCasesWithAMissingStoryAndDuplicateInheritedEpics() throws Exception {
        CheckerResult result = runChecker(VALID_INTEGRATION_TEST, """
            @JIRA-EPIC:PO-6506
            Feature: Example
              @JIRA-EPIC:PO-10817
              Scenario: A journey with conflicting ownership
                Given a supported precondition
            """);

        assertEquals(1, result.exitCode(), result.output());
        assertTrue(result.output().contains("missing @JIRA-STORY tag"), result.output());
        assertTrue(result.output().contains("has 2 @JIRA-EPIC tags"), result.output());
    }

    @Test
    void acceptsMultipleStoriesOnAParameterizedMethodWithWrappedAnnotations() throws Exception {
        CheckerResult result = runChecker("""
            class ExampleIntegrationTest {
                @ParameterizedTest
                @JiraStory(
                    "PO-10251"
                )
                @JiraStory("PO-10290")
                @JiraEpic("PO-6506")
                void example(
                    String value
                ) {}
            }
            """, VALID_FEATURE);

        assertEquals(0, result.exitCode(), result.output());
        assertTrue(result.output().contains("1 runnable integration test method(s)"), result.output());
    }

    @Test
    void acceptsAnExplicitlyRegisteredInfrastructureExemption() throws Exception {
        CheckerResult result = runChecker("""
            class ExampleIntegrationTest {
                @Test
                @JiraIgnore
                void example() {}
            }
            """, VALID_FEATURE, "ExampleIntegrationTest#example\n");

        assertEquals(0, result.exitCode(), result.output());
        assertTrue(result.output().contains("1 explicitly exempted infrastructure method(s)"), result.output());
    }

    @Test
    void rejectsAnUnregisteredIgnoreMarkerEvenWhenOwnershipTagsArePresent() throws Exception {
        CheckerResult result = runChecker("""
            class ExampleIntegrationTest {
                @Test
                @JiraStory("PO-10251")
                @JiraEpic("PO-6506")
                @JiraIgnore
                void example() {}
            }
            """, VALID_FEATURE);

        assertEquals(1, result.exitCode(), result.output());
        assertTrue(result.output().contains("requires an explicitly approved infrastructure metadata exemption"),
            result.output());
    }

    @Test
    void rejectsAStaleExemptionEntry() throws Exception {
        CheckerResult result = runChecker(VALID_INTEGRATION_TEST, VALID_FEATURE,
            "ExampleIntegrationTest#removedMethod\n");

        assertEquals(1, result.exitCode(), result.output());
        assertTrue(result.output().contains("Exemptions do not match an explicitly marked integration test"),
            result.output());
    }

    @Test
    void rejectsAClassWideMetadataExemption() throws Exception {
        CheckerResult result = runChecker("""
            @JiraIgnore
            class ExampleIntegrationTest {
                @Test
                @JiraStory("PO-10251")
                @JiraEpic("PO-6506")
                void example() {}
            }
            """, VALID_FEATURE);

        assertEquals(1, result.exitCode(), result.output());
        assertTrue(result.output().contains("only supported on explicitly listed test methods"), result.output());
    }

    private CheckerResult runChecker(String integrationSource, String featureSource) throws Exception {
        return runChecker(integrationSource, featureSource, null);
    }

    private CheckerResult runChecker(
        String integrationSource, String featureSource, String exemptions) throws Exception {

        Path integrationRoot = Files.createDirectories(temporaryDirectory.resolve("integration"));
        Path featureRoot = Files.createDirectories(temporaryDirectory.resolve("features"));
        Files.writeString(integrationRoot.resolve("ExampleIntegrationTest.java"), integrationSource);
        Files.writeString(featureRoot.resolve("example.feature"), featureSource);
        Path checkerClasses = Path.of(TestJiraAnnotationChecker.class.getProtectionDomain().getCodeSource()
            .getLocation().toURI());
        Path javaExecutable = Path.of(System.getProperty("java.home"), "bin", "java");

        ProcessBuilder builder = new ProcessBuilder(javaExecutable.toString(), "-cp", checkerClasses.toString(),
            TestJiraAnnotationChecker.class.getName(), integrationRoot.toString(), featureRoot.toString());
        if (exemptions != null) {
            Path exemptionFile = temporaryDirectory.resolve("metadata-exemptions.txt");
            Files.writeString(exemptionFile, exemptions);
            builder.command().add(exemptionFile.toString());
        }
        Process process = builder.redirectErrorStream(true).start();
        try {
            assertTrue(process.waitFor(30, TimeUnit.SECONDS), "Jira metadata checker did not finish");
            try (InputStream output = process.getInputStream()) {
                return new CheckerResult(process.exitValue(),
                    new String(output.readAllBytes(), StandardCharsets.UTF_8));
            }
        } finally {
            process.destroyForcibly();
        }
    }

    private record CheckerResult(int exitCode, String output) {
    }
}
