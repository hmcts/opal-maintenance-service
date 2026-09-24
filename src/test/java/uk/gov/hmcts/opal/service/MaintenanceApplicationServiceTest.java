package uk.gov.hmcts.opal.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.NullSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.mapstruct.factory.Mappers;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import uk.gov.hmcts.opal.entity.MaintenanceApplicationEntity;
import uk.gov.hmcts.opal.mapper.MaintenanceApplicationMapper;
import uk.gov.hmcts.opal.repository.MaintenanceApplicationRepository;

@ExtendWith(MockitoExtension.class)
class MaintenanceApplicationServiceTest {

    @Mock
    private MaintenanceApplicationRepository repository;

    private MaintenanceApplicationService service;

    @BeforeEach
    void setUp() {
        service = new MaintenanceApplicationService(repository, Mappers.getMapper(MaintenanceApplicationMapper.class));
    }

    @ParameterizedTest
    @NullSource
    @ValueSource(booleans = {true, false})
    void mapsRowsAndPassesFiltersUnchanged(Boolean active) {
        var row = MaintenanceApplicationEntity.builder()
            .applicationId((short) 32001).applicationCode("APP00001")
            .applicationTitle("Example").applicationGroup("Create Casefile").active(false).build();
        when(repository.findMaintenanceApplications("Create Casefile", active)).thenReturn(List.of(row));

        var response = service.getMaintenanceApplications("Create Casefile", active);

        assertThat(response.getCount()).isEqualTo(1);
        assertThat(response.getRefData()).singleElement().satisfies(item -> {
            assertThat(item.getApplicationId()).isEqualTo((short) 32001);
            assertThat(item.getApplicationCode()).isEqualTo("APP00001");
            assertThat(item.getApplicationTitle()).isEqualTo("Example");
            assertThat(item.getApplicationGroup()).isEqualTo("Create Casefile");
            assertThat(item.getActive()).isFalse();
        });
        verify(repository).findMaintenanceApplications("Create Casefile", active);
    }

    @Test
    void returnsSuccessfulEmptyCollection() {
        when(repository.findMaintenanceApplications("Unknown", null)).thenReturn(List.of());
        var response = service.getMaintenanceApplications("Unknown", null);
        assertThat(response.getCount()).isZero();
        assertThat(response.getRefData()).isEmpty();
    }
}
