package uk.gov.hmcts.opal.service;

import jakarta.persistence.EntityNotFoundException;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.jspecify.annotations.Nullable;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import uk.gov.hmcts.opal.generated.model.ResultDetailResponse;
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
    @Cacheable(cacheNames = "resultDetailCache", key = "#resultId")
    public ResultDetailResponse getResult(String resultId) {
        return mapper.toDetailResponse(repository.findById(resultId)
            .orElseThrow(() -> new EntityNotFoundException("Result not found")));
    }

    @Transactional(readOnly = true)
    @Cacheable(
        cacheNames = "resultReferenceDataCache",
        key = "(#orderTerm == null ? 'noFilter' : #orderTerm.toString()) + '_' + "
            + "(#active == null ? 'noFilter' : #active.toString())"
    )
    public ResultReferenceDataResponse getResults(
        @Nullable Boolean orderTerm, @Nullable Boolean active
    ) {
        List<ResultReferenceDataItem> items = repository.findResults(orderTerm, active).stream()
            .map(mapper::toReferenceDataItem).toList();
        return ResultReferenceDataResponse.builder().count(items.size()).refData(items).build();
    }
}
