package site.thaonv.voca.apikey;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface ApiKeyRepository extends JpaRepository<ApiKey, Long> {
    Optional<ApiKey> findByKeyHash(String keyHash);

    List<ApiKey> findByClient_OwnerUserIdOrderByCreatedAtDesc(Long ownerUserId);

    void deleteByClient_Id(Long clientId);
}
