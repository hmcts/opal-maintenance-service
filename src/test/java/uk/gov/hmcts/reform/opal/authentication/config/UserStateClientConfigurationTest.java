package uk.gov.hmcts.reform.opal.authentication.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.core.StringRedisTemplate;
import uk.gov.hmcts.opal.common.user.authorisation.client.UserClient;
import uk.gov.hmcts.opal.common.user.authorisation.client.dto.UserStateDto;
import uk.gov.hmcts.opal.common.user.authorisation.client.mapper.UserStateMapper;
import uk.gov.hmcts.opal.common.user.authorisation.client.mapper.UserStateMapperImpl;
import uk.gov.hmcts.opal.common.user.authorisation.client.service.UserStateClientService;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.clearInvocations;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

class UserStateClientConfigurationTest {

    private final UserClient userClient = mock();
    private final StringRedisTemplate redisTemplate = mock();
    private final ObjectMapper objectMapper = mock();

    private final ApplicationContextRunner contextRunner = new ApplicationContextRunner()
        .withUserConfiguration(UserStateClientConfiguration.class, CachingTestConfiguration.class)
        .withBean(UserClient.class, () -> userClient)
        .withBean(UserStateMapper.class, UserStateMapperImpl::new)
        .withBean(StringRedisTemplate.class, () -> redisTemplate)
        .withBean(ObjectMapper.class, () -> objectMapper);

    @Test
    void disablesInheritedCachingAndResolvesAuthenticatedUserDirectly() {
        UserStateDto userStateDto = UserStateDto.builder()
            .userId(123L)
            .username("test-user@example.invalid")
            .businessUnitUsers(List.of())
            .build();
        when(userClient.getUserStateById(0L)).thenReturn(userStateDto);

        contextRunner
            .withPropertyValues("opal.redis.enabled=false")
            .run(context -> {
                UserStateClientService service = context.getBean(UserStateClientService.class);
                clearInvocations(redisTemplate, objectMapper);

                assertThat(service.getUserStateByAuthenticatedUser()).isPresent();
                assertThat(service.getUserStateByAuthenticatedUser()).isPresent();
                verify(userClient, times(2)).getUserStateById(0L);
                verifyNoInteractions(redisTemplate, objectMapper);
            });
    }

    @Configuration
    @EnableCaching
    static class CachingTestConfiguration {
    }
}
