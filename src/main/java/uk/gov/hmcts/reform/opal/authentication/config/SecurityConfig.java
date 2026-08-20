package uk.gov.hmcts.reform.opal.authentication.config;

import jakarta.servlet.DispatcherType;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.annotation.web.configurers.FormLoginConfigurer;
import org.springframework.security.config.annotation.web.configurers.LogoutConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.oauth2.server.resource.authentication.JwtIssuerAuthenticationManagerResolver;
import org.springframework.security.web.SecurityFilterChain;
import uk.gov.hmcts.opal.common.user.authentication.exception.CustomAuthenticationExceptions;

@Configuration
public class SecurityConfig {

    private static final String[] PUBLIC_GET_ENDPOINTS = {
        "/", "/health", "/prometheus", "/swagger-ui.html", "/swagger-ui/**",
        "/v3/api-docs", "/v3/api-docs.yaml", "/v3/api-docs/swagger-config"
    };

    private final CustomAuthenticationExceptions customAuthenticationExceptions;
    private final PrivacyPreservingOauth2AuthenticationEntryPoint oauth2AuthenticationEntryPoint;

    public SecurityConfig(
        CustomAuthenticationExceptions customAuthenticationExceptions,
        PrivacyPreservingOauth2AuthenticationEntryPoint oauth2AuthenticationEntryPoint) {
        this.customAuthenticationExceptions = customAuthenticationExceptions;
        this.oauth2AuthenticationEntryPoint = oauth2AuthenticationEntryPoint;
    }

    // CSRF does not apply: this stateless API authenticates only explicit bearer credentials.
    @Bean
    @SuppressWarnings("squid:S4502")
    public SecurityFilterChain filterChain(
        HttpSecurity http,
        JwtIssuerAuthenticationManagerResolver resolver,
        @Value("${opal.testing-support-endpoints.enabled:false}") boolean testingSupportEnabled) throws Exception {
        http.sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .csrf(AbstractHttpConfigurer::disable)
            .formLogin(FormLoginConfigurer::disable)
            .logout(LogoutConfigurer::disable)
            .authorizeHttpRequests(authorize -> {
                authorize.dispatcherTypeMatchers(DispatcherType.ERROR).permitAll();
                authorize.requestMatchers(HttpMethod.GET, PUBLIC_GET_ENDPOINTS).permitAll();
                if (testingSupportEnabled) {
                    authorize.requestMatchers(HttpMethod.GET, "/testing-support/ping").permitAll();
                    authorize.requestMatchers(HttpMethod.GET, "/testing-support/auth/check").authenticated();
                } else {
                    authorize.requestMatchers(
                        HttpMethod.GET,
                        "/testing-support/ping",
                        "/testing-support/auth/check"
                    ).permitAll();
                }
                authorize.anyRequest().authenticated();
            })
            .exceptionHandling(errors -> errors
                .authenticationEntryPoint(customAuthenticationExceptions)
                .accessDeniedHandler(customAuthenticationExceptions))
            .oauth2ResourceServer(oauth -> oauth
                .authenticationManagerResolver(resolver)
                .authenticationEntryPoint(oauth2AuthenticationEntryPoint));
        return http.build();
    }
}
