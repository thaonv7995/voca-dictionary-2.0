package site.thaonv.voca.user;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

/** Seeds a default admin user on first boot so the API-key admin endpoints are reachable. */
@Component
@Order(10)
public class AdminSeedRunner implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(AdminSeedRunner.class);

    private final UserRepository users;
    private final PasswordEncoder encoder;
    private final String adminEmail;
    private final String adminPassword;

    public AdminSeedRunner(UserRepository users,
                           PasswordEncoder encoder,
                           @Value("${app.admin.email:admin@voca.local}") String adminEmail,
                           @Value("${app.admin.password:change-me}") String adminPassword) {
        this.users = users;
        this.encoder = encoder;
        this.adminEmail = adminEmail;
        this.adminPassword = adminPassword;
    }

    @Override
    public void run(ApplicationArguments args) {
        if (users.existsByAdminTrue()) {
            return;
        }
        User admin = new User();
        admin.setEmail(adminEmail);
        admin.setPasswordHash(encoder.encode(adminPassword));
        admin.setDisplayName("Administrator");
        admin.setAdmin(true);
        users.save(admin);
        log.warn("Seeded default admin '{}'. CHANGE THE PASSWORD via /api/auth/change-password or config.", adminEmail);
    }
}
