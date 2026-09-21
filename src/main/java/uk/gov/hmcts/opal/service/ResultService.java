package uk.gov.hmcts.opal.service;

import java.util.List;
import lombok.RequiredArgsConstructor;
import org.jspecify.annotations.Nullable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import uk.gov.hmcts.opal.generated.model.ResultReferenceDataItem;
import uk.gov.hmcts.opal.generated.model.ResultReferenceDataResponse;
import uk.gov.hmcts.opal.mapper.ResultMapper;
import uk.gov.hmcts.opal.repository.ResultRepository;

@Service
@RequiredArgsConstructor
public class ResultService {

    private final ResultRepository repository;
    private final ResultMapper mapper;

    @Transactional(readOnly = true)
    public ResultReferenceDataResponse getResults(
        @Nullable Boolean orderTerm, @Nullable Boolean active
    ) {
        List<ResultReferenceDataItem> items = repository.findResults(orderTerm, active).stream()
            .map(mapper::toReferenceDataItem).toList();
        return ResultReferenceDataResponse.builder().count(items.size()).refData(items).build();
    }
}
