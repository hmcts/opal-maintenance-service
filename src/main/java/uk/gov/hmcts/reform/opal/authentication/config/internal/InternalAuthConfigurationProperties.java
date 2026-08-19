package uk.gov.hmcts.reform.opal.authentication.config.internal;

import jakarta.validation.constraints.NotBlank;
import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;
import org.springframework.validation.annotation.Validated;
import uk.gov.hmcts.opal.common.user.authentication.config.AuthConfigurationProperties;

@Component
@ConfigurationProperties("spring.security.oauth2.client.registration.internal-azure-ad")
@Validated
@Getter
@Setter
public class InternalAuthConfigurationProperties implements AuthConfigurationProperties {

    @NotBlank(message = "Internal AAD client ID must be configured")
    private String clientId;
    private String clientSecret;
    private String scope;
    private String redirectUri;
    private String logoutRedirectUri;
    private String grantType;
    private String responseType;
    private String responseMode;
    private String prompt;
    private String issuerUri;
    private String claims;
}
