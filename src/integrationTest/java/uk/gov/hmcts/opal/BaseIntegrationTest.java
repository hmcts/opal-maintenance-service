package uk.gov.hmcts.opal;

import java.nio.file.Path;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.images.builder.ImageFromDockerfile;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

@Testcontainers
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles({"integration"})
@SuppressWarnings("HideUtilityClassConstructor")
public class BaseIntegrationTest {

    private static final ImageFromDockerfile POSTGRES_PGTAP_IMAGE = new ImageFromDockerfile()
        .withFileFromPath(
            "Dockerfile",
            Path.of("docker/postgres-pgtap.Dockerfile").toAbsolutePath()
        );

    @ServiceConnection
    @Container
    protected static PostgreSQLContainer databaseContainer = new PostgreSQLContainer(
        DockerImageName.parse(POSTGRES_PGTAP_IMAGE.get()).asCompatibleSubstituteFor("postgres")
    );

    @DynamicPropertySource
    static void databaseProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", databaseContainer::getJdbcUrl);
        registry.add("spring.datasource.username", databaseContainer::getUsername);
        registry.add("spring.datasource.password", databaseContainer::getPassword);
    }
}
