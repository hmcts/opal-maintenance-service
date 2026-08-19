package uk.gov.hmcts.reform.opal.authentication.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.security.autoconfigure.web.servlet.PathRequest;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
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

    private static final String[] PUBLIC_ENDPOINTS = {
        "/swagger-ui.html", "/swagger-ui/**", "/swagger-resources/**", "/v3/**",
        "/favicon.ico", "/health/**", "/info", "/prometheus", "/"
    };

    private final CustomAuthenticationExceptions customAuthenticationExceptions;
    private final PrivacyPreservingOauth2AuthenticationEntryPoint oauth2AuthenticationEntryPoint;

    public SecurityConfig(
        CustomAuthenticationExceptions customAuthenticationExceptions,
        PrivacyPreservingOauth2AuthenticationEntryPoint oauth2AuthenticationEntryPoint) {
        this.customAuthenticationExceptions = customAuthenticationExceptions;
        this.oauth2AuthenticationEntryPoint = oauth2AuthenticationEntryPoint;
    }

    @Bean
    public SecurityFilterChain filterChain(
        HttpSecurity http,
        JwtIssuerAuthenticationManagerResolver resolver,
        @Value("${opal.testing-support-endpoints.enabled:false}") boolean testingSupportEnabled) throws Exception {
        http.sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .csrf(AbstractHttpConfigurer::disable)
            .formLogin(FormLoginConfigurer::disable)
            .logout(LogoutConfigurer::disable)
            .authorizeHttpRequests(authorize -> {
                authorize.requestMatchers(PathRequest.toStaticResources().atCommonLocations()).permitAll();
                authorize.requestMatchers(PUBLIC_ENDPOINTS).permitAll();
                if (testingSupportEnabled) {
                    authorize.requestMatchers("/testing-support/auth/**").authenticated();
                }
                authorize.requestMatchers("/testing-support/**").permitAll();
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
