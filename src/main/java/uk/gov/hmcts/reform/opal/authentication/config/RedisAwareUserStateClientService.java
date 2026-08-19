package uk.gov.hmcts.reform.opal.authentication.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import feign.FeignException;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.security.oauth2.jwt.Jwt;
import uk.gov.hmcts.opal.common.user.authorisation.client.UserClient;
import uk.gov.hmcts.opal.common.user.authorisation.client.dto.UserStateV2Dto;
import uk.gov.hmcts.opal.common.user.authorisation.client.mapper.UserStateMapper;
import uk.gov.hmcts.opal.common.user.authorisation.client.service.UserStateClientService;
import uk.gov.hmcts.opal.common.user.authorisation.model.UserStateV2;

import java.util.Optional;

public class RedisAwareUserStateClientService extends UserStateClientService {

    private final UserClient userClient;
    private final UserStateMapper userStateMapper;
    private final boolean redisEnabled;

    public RedisAwareUserStateClientService(
        UserClient userClient,
        UserStateMapper userStateMapper,
        StringRedisTemplate redisTemplate,
        ObjectMapper objectMapper,
        boolean redisEnabled) {
        super(userClient, userStateMapper, redisTemplate, objectMapper);
        this.userClient = userClient;
        this.userStateMapper = userStateMapper;
        this.redisEnabled = redisEnabled;
    }

    @Override
    public Optional<UserStateV2> getUserStateByAuthenticationToken(Jwt jwt) {
        if (redisEnabled) {
            return super.getUserStateByAuthenticationToken(jwt);
        }

        try {
            UserStateV2Dto userState = userClient.getUserStateByIdWithAuthToken("Bearer " + jwt.getTokenValue());
            return Optional.ofNullable(userState).map(userStateMapper::toUserStateV2);
        } catch (FeignException.NotFound exception) {
            return Optional.empty();
        }
    }
}
