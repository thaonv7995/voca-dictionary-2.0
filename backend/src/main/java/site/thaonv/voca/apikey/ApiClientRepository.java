package site.thaonv.voca.apikey;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface ApiClientRepository extends JpaRepository<ApiClient, Long> {

    List<ApiClient> findByOwnerUserId(Long ownerUserId);

    Optional<ApiClient> findFirstByOwnerUserId(Long ownerUserId);
}
