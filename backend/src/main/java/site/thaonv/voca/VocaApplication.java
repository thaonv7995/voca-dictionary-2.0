package site.thaonv.voca;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableAsync;

@SpringBootApplication
@EnableAsync
public class VocaApplication {
    public static void main(String[] args) {
        SpringApplication.run(VocaApplication.class, args);
    }
}
