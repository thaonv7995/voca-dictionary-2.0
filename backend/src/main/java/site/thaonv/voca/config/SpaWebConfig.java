package site.thaonv.voca.config;

import org.springframework.core.io.ClassPathResource;
import org.springframework.core.io.Resource;
import org.springframework.lang.NonNull;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.resource.PathResourceResolver;

import java.io.IOException;

/**
 * Serves the embedded single-page app from classpath:/static/ and falls back to index.html for
 * client-side routes, while leaving /api/** and /v1/** to their controllers. This is what makes the
 * fat jar a single binary on a single port (API + web served together).
 */
@Component
public class SpaWebConfig implements WebMvcConfigurer {

    @Override
    public void addResourceHandlers(@NonNull ResourceHandlerRegistry registry) {
        registry.addResourceHandler("/**")
                .addResourceLocations("classpath:/static/")
                .resourceChain(true)
                .addResolver(new PathResourceResolver() {
                    @Override
                    protected Resource getResource(@NonNull String resourcePath, @NonNull Resource location)
                            throws IOException {
                        Resource requested = location.createRelative(resourcePath);
                        if (requested.exists() && requested.isReadable()) {
                            return requested;
                        }
                        // API namespaces must never be shadowed by the SPA fallback.
                        if (resourcePath.startsWith("api/") || resourcePath.startsWith("v1/")
                                || resourcePath.startsWith("actuator/") || resourcePath.startsWith("swagger")
                                || resourcePath.startsWith("v3/api-docs")) {
                            return null;
                        }
                        Resource index = new ClassPathResource("/static/index.html");
                        return index.exists() ? index : null;
                    }
                });
    }
}
