package uk.gov.hmcts.reform.opal;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.cloud.openfeign.EnableFeignClients;
import uk.gov.hmcts.reform.opal.config.FeignConfiguration;

@SpringBootApplication(scanBasePackages = {
    "uk.gov.hmcts.reform.opal",
    "uk.gov.hmcts.opal.common"
})
@EnableFeignClients(
    basePackages = "uk.gov.hmcts.opal.common.user.authorisation.client",
    defaultConfiguration = FeignConfiguration.class
)
@EnableCaching
@ConfigurationPropertiesScan
@SuppressWarnings("HideUtilityClassConstructor") // Spring needs a constructor, its not a utility class
public class Application {

    public static void main(final String[] args) {
        SpringApplication.run(Application.class, args);
    }
}
