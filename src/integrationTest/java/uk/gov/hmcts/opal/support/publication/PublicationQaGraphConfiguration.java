package uk.gov.hmcts.opal.support.publication;

import jakarta.persistence.EntityManager;
import org.springframework.boot.persistence.autoconfigure.EntityScan;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.transaction.PlatformTransactionManager;
import tools.jackson.databind.ObjectMapper;
import uk.gov.hmcts.opal.entity.DraftCasefileEntity;
import uk.gov.hmcts.opal.repository.CountryRepository;
import uk.gov.hmcts.opal.repository.MaintenanceApplicationRepository;
import uk.gov.hmcts.opal.repository.MajorCreditorRepository;
import uk.gov.hmcts.opaltest.publication.PublicationQaRespondent;

@TestConfiguration(proxyBeanMethods = false)
@EntityScan(basePackageClasses = {DraftCasefileEntity.class, PublicationQaRespondent.class})
public class PublicationQaGraphConfiguration {

    @Bean
    PublicationQaGraph publicationQaGraph(EntityManager entities, PlatformTransactionManager transactions,
                                         ObjectMapper json, CountryRepository countries,
                                         MaintenanceApplicationRepository applications,
                                         MajorCreditorRepository majorCreditors) {
        return new PublicationQaGraph(entities, transactions, json, countries, applications, majorCreditors);
    }
}
