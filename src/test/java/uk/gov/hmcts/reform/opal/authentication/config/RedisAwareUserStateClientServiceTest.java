package uk.gov.hmcts.reform.opal.authentication.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InOrder;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.security.oauth2.jwt.Jwt;
import uk.gov.hmcts.opal.common.user.authorisation.client.UserClient;
import uk.gov.hmcts.opal.common.user.authorisation.client.dto.BusinessUnitUserDto;
import uk.gov.hmcts.opal.common.user.authorisation.client.dto.DomainDto;
import uk.gov.hmcts.opal.common.user.authorisation.client.dto.PermissionDto;
import uk.gov.hmcts.opal.common.user.authorisation.client.dto.UserStateV2Dto;
import uk.gov.hmcts.opal.common.user.authorisation.client.mapper.UserStateMapper;
import uk.gov.hmcts.opal.common.user.authorisation.client.mapper.UserStateMapperImpl;
import uk.gov.hmcts.opal.common.user.authorisation.model.BusinessUnitUser;
import uk.gov.hmcts.opal.common.user.authorisation.model.Domain;
import uk.gov.hmcts.opal.common.user.authorisation.model.Permission;
import uk.gov.hmcts.opal.common.user.authorisation.model.UserStateV2;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class RedisAwareUserStateClientServiceTest {

    private static final String CACHE_KEY = "USER_STATE_subject-123";
    private static final String CACHED_JSON = "{\"cached\":true}";
    private static final String TOKEN_VALUE = "token-abc";

    @Mock
    private UserClient userClient;

    @Mock
    private StringRedisTemplate redisTemplate;

    @Mock
    private ObjectMapper objectMapper;

    @Mock
    private ValueOperations<String, String> valueOperations;

    private UserStateMapper userStateMapper;

    @BeforeEach
    void setUp() {
        userStateMapper = new UserStateMapperImpl();
    }

    @Test
    void resolvesCompleteUserStateDirectlyWhenRedisIsDisabled() {
        UserStateV2Dto userStateDto = completeUserStateDto();
        when(userClient.getUserStateByIdWithAuthToken("Bearer " + TOKEN_VALUE)).thenReturn(userStateDto);
        RedisAwareUserStateClientService service = serviceWithRedisEnabled(false);

        UserStateV2 userState = service.getUserStateByAuthenticationToken(jwt()).orElseThrow();

        assertCompleteUserState(userState);
        verify(userClient).getUserStateByIdWithAuthToken("Bearer " + TOKEN_VALUE);
        verifyNoInteractions(redisTemplate, valueOperations, objectMapper);
    }

    @Test
    void returnsCachedUserStateWithoutCallingUserServiceWhenRedisIsEnabled() throws Exception {
        UserStateV2Dto userStateDto = completeUserStateDto();
        when(redisTemplate.opsForValue()).thenReturn(valueOperations);
        when(valueOperations.get(CACHE_KEY)).thenReturn(CACHED_JSON);
        when(objectMapper.readValue(CACHED_JSON, UserStateV2Dto.class)).thenReturn(userStateDto);
        RedisAwareUserStateClientService service = serviceWithRedisEnabled(true);

        UserStateV2 userState = service.getUserStateByAuthenticationToken(jwt()).orElseThrow();

        assertCompleteUserState(userState);
        verifyNoInteractions(userClient);
    }

    @Test
    void readsCacheBeforeCallingUserServiceWithExactBearerWhenRedisIsEnabled() {
        UserStateV2Dto userStateDto = completeUserStateDto();
        when(redisTemplate.opsForValue()).thenReturn(valueOperations);
        when(valueOperations.get(CACHE_KEY)).thenReturn(null);
        when(userClient.getUserStateByIdWithAuthToken("Bearer " + TOKEN_VALUE)).thenReturn(userStateDto);
        RedisAwareUserStateClientService service = serviceWithRedisEnabled(true);

        UserStateV2 userState = service.getUserStateByAuthenticationToken(jwt()).orElseThrow();

        assertCompleteUserState(userState);
        InOrder lookupOrder = inOrder(valueOperations, userClient);
        lookupOrder.verify(valueOperations).get(CACHE_KEY);
        lookupOrder.verify(userClient).getUserStateByIdWithAuthToken("Bearer " + TOKEN_VALUE);
    }

    private RedisAwareUserStateClientService serviceWithRedisEnabled(boolean redisEnabled) {
        return new RedisAwareUserStateClientService(
            userClient,
            userStateMapper,
            redisTemplate,
            objectMapper,
            redisEnabled
        );
    }

    private static Jwt jwt() {
        return Jwt.withTokenValue(TOKEN_VALUE)
            .header("alg", "RS256")
            .subject("subject-123")
            .build();
    }

    private static UserStateV2Dto completeUserStateDto() {
        PermissionDto permission = new PermissionDto(9L, "MANAGE_CASES");
        BusinessUnitUserDto businessUnitUser = new BusinessUnitUserDto(
            "BUU-42",
            (short) 42,
            List.of(permission)
        );
        return new UserStateV2Dto(
            123L,
            "test-user@example.invalid",
            "Test User",
            "ACTIVE",
            7L,
            "user-state-cache",
            Map.of(Domain.MAINTENANCE, new DomainDto(List.of(businessUnitUser)))
        );
    }

    private static void assertCompleteUserState(UserStateV2 userState) {
        assertThat(userState.getUserId()).isEqualTo(123L);
        assertThat(userState.getUsername()).isEqualTo("test-user@example.invalid");
        assertThat(userState.getName()).isEqualTo("Test User");
        assertThat(userState.getStatus().name()).isEqualTo("ACTIVE");
        assertThat(userState.getVersion()).isEqualTo(7L);
        assertThat(userState.getCacheName()).isEqualTo("user-state-cache");

        BusinessUnitUser businessUnitUser = userState.getDomainBusinessUnitUsers(Domain.MAINTENANCE)
            .getBusinessUnitUsers()
            .getFirst();
        assertThat(businessUnitUser.getBusinessUnitUserId()).isEqualTo("BUU-42");
        assertThat(businessUnitUser.getBusinessUnitId()).isEqualTo((short) 42);
        Permission permission = businessUnitUser.getPermissions().iterator().next();
        assertThat(permission.getPermissionId()).isEqualTo(9L);
        assertThat(permission.getPermissionName()).isEqualTo("MANAGE_CASES");
    }
}
