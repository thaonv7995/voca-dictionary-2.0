package site.thaonv.voca.common;

import org.springframework.core.MethodParameter;
import org.springframework.http.MediaType;
import org.springframework.http.converter.HttpMessageConverter;
import org.springframework.http.converter.json.MappingJackson2HttpMessageConverter;
import org.springframework.http.server.ServerHttpRequest;
import org.springframework.http.server.ServerHttpResponse;
import org.springframework.http.server.ServletServerHttpResponse;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.servlet.mvc.method.annotation.ResponseBodyAdvice;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Wraps our JSON API responses (/api/**, /v1/**) in a consistent { status, code, message, data }
 * envelope. Only JSON goes through here — SSE streams, audio bytes and the Markdown docs use other
 * converters and are left untouched, as are actuator/springdoc endpoints (outside /api and /v1).
 */
@RestControllerAdvice
public class ApiResponseWrapper implements ResponseBodyAdvice<Object> {

    @Override
    public boolean supports(MethodParameter returnType, Class<? extends HttpMessageConverter<?>> converterType) {
        return MappingJackson2HttpMessageConverter.class.isAssignableFrom(converterType);
    }

    @Override
    public Object beforeBodyWrite(Object body, MethodParameter returnType, MediaType selectedContentType,
                                  Class<? extends HttpMessageConverter<?>> selectedConverterType,
                                  ServerHttpRequest request, ServerHttpResponse response) {
        String path = request.getURI().getPath();
        if (!(path.startsWith("/api/") || path.startsWith("/v1/") || path.equals("/api") || path.equals("/v1"))) {
            return body;
        }
        // Already-enveloped bodies (e.g. errors from GlobalExceptionHandler) pass through unchanged.
        if (body instanceof Map<?, ?> m && m.containsKey("status") && m.containsKey("code") && m.containsKey("data")) {
            return body;
        }
        int status = 200;
        if (response instanceof ServletServerHttpResponse s) {
            status = s.getServletResponse().getStatus();
        }
        Map<String, Object> env = new LinkedHashMap<>();
        env.put("status", status);
        env.put("code", "OK");
        env.put("message", "Success");
        env.put("data", body);
        return env;
    }
}
