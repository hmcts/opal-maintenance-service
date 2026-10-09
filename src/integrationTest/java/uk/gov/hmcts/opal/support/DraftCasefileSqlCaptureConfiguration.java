package uk.gov.hmcts.opal.support;

import org.hibernate.resource.jdbc.spi.StatementInspector;
import org.springframework.boot.hibernate.autoconfigure.HibernatePropertiesCustomizer;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;

import java.util.List;
import java.util.Locale;
import java.util.concurrent.CopyOnWriteArrayList;

@TestConfiguration(proxyBeanMethods = false)
public class DraftCasefileSqlCaptureConfiguration {
    @Bean
    public StatementCapture statementCapture() {
        return new StatementCapture();
    }

    @Bean
    public HibernatePropertiesCustomizer captureSql(StatementCapture capture) {
        return properties -> properties.put("hibernate.session_factory.statement_inspector", capture);
    }

    public static final class StatementCapture implements StatementInspector {
        private final List<String> statements = new CopyOnWriteArrayList<>();

        @Override
        public String inspect(String sql) {
            statements.add(sql);
            return sql;
        }

        public void clear() {
            statements.clear();
        }

        public List<String> draftSelects() {
            return statements.stream()
                .filter(sql -> sql.toLowerCase(Locale.ROOT).contains("from draft_casefiles"))
                .toList();
        }
    }
}
