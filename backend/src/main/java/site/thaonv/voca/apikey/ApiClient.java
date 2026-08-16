package site.thaonv.voca.apikey;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;

/** A registered third-party consumer of the Voca API (e.g. bilingual-app). Owns 0..n API keys. */
@Entity
@Table(name = "api_clients")
@Getter
@Setter
@NoArgsConstructor
public class ApiClient {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String name;

    private String description;

    @Column(name = "owner_user_id")
    private Long ownerUserId;

    @Column(name = "contact_email")
    private String contactEmail;

    @Column(nullable = false)
    private String status = "active";

    @Column(name = "created_at", nullable = false)
    private Instant createdAt = Instant.now();
}
