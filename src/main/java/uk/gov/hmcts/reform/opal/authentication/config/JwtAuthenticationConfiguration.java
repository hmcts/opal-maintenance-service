package uk.gov.hmcts.reform.opal.authentication.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.oauth2.jose.jws.SignatureAlgorithm;
import org.springframework.security.oauth2.jwt.JwtAudienceValidator;
import org.springframework.security.oauth2.jwt.JwtIssuerValidator;
import org.springframework.security.oauth2.jwt.JwtValidators;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.server.resource.authentication.JwtGrantedAuthoritiesConverter;
import org.springframework.security.oauth2.server.resource.authentication.JwtIssuerAuthenticationManagerResolver;
import uk.gov.hmcts.opal.common.config.OpalCommonConfiguration;
import uk.gov.hmcts.opal.common.spring.security.OpalJwtAuthenticationProvider;
import uk.gov.hmcts.opal.common.user.authorisation.client.service.UserStateClientService;
import uk.gov.hmcts.opal.common.user.authorisation.model.Domain;
import uk.gov.hmcts.reform.opal.authentication.config.internal.InternalAuthConfigurationProperties;
import uk.gov.hmcts.reform.opal.authentication.config.internal.InternalAuthProviderConfigurationProperties;

import java.util.List;
import java.util.Map;

@Configuration
public class JwtAuthenticationConfiguration {

    @Bean
    JwtIssuerAuthenticationManagerResolver jwtIssuerAuthenticationManagerResolver(
        InternalAuthConfigurationProperties authProperties,
        OpalJwtAuthenticationProvider authenticationProvider) {
        AuthenticationManager manager = authenticationProvider::authenticate;
        Map<String, AuthenticationManager> managers = Map.of(authProperties.getIssuerUri(), manager);
        return new JwtIssuerAuthenticationManagerResolver(managers::get);
    }

    @Bean
    OpalJwtAuthenticationProvider opalJwtAuthenticationProvider(
        NimbusJwtDecoder jwtDecoder,
        UserStateClientService userStateClientService,
        JwtGrantedAuthoritiesConverter authoritiesConverter,
        OpalCommonConfiguration commonConfiguration) {
        Domain domain = Domain.findByDisplayName(commonConfiguration.getDomain());
        return new OpalJwtAuthenticationProvider(jwtDecoder, userStateClientService, authoritiesConverter, domain);
    }

    @Bean
    NimbusJwtDecoder internalJwtDecoder(
        InternalAuthProviderConfigurationProperties providerProperties,
        InternalAuthConfigurationProperties authProperties) {
        NimbusJwtDecoder decoder = NimbusJwtDecoder.withJwkSetUri(providerProperties.getJwkSetUri())
            .jwsAlgorithm(SignatureAlgorithm.RS256)
            .build();
        decoder.setJwtValidator(JwtValidators.createDefaultWithValidators(List.of(
            new JwtIssuerValidator(authProperties.getIssuerUri()),
            new JwtAudienceValidator(authProperties.getClientId())
        )));
        return decoder;
    }

    @Bean
    JwtGrantedAuthoritiesConverter jwtGrantedAuthoritiesConverter() {
        return new JwtGrantedAuthoritiesConverter();
    }
}
