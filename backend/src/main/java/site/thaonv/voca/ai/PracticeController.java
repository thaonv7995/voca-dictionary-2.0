package site.thaonv.voca.ai;

import org.springframework.http.MediaType;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import site.thaonv.voca.user.UserPrincipal;

import java.util.List;

/** App-facing streaming practice generators + assistant (JWT). Each streams LLM output over SSE. */
@RestController
@RequestMapping("/api")
public class PracticeController {

    private static final String DEFAULT_CONTEXT = "All words";
    private static final String DEFAULT_WEAKNESS = "No recorded practice mistakes yet.";
    private static final int INDEX_LIMIT = 60;

    private final PracticeService practice;
    private final PracticePrompts prompts;

    public PracticeController(PracticeService practice, PracticePrompts prompts) {
        this.practice = practice;
        this.prompts = prompts;
    }

    public record DrillRequest(Integer count, String selectedWord, String context) {
    }

    public record ReadingRequest(String selectedWord, String format, String context) {
    }

    public record GenRequest(String selectedWord, String context) {
    }

    public record ChatRequest(String message) {
    }

    @PostMapping(value = "/practice/drills", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter drills(@RequestBody(required = false) DrillRequest req,
                             @AuthenticationPrincipal UserPrincipal principal) {
        int count = req != null && req.count() != null ? req.count() : 5;
        String selected = req != null ? req.selectedWord() : null;
        String context = req != null && req.context() != null ? req.context() : DEFAULT_CONTEXT;
        String prompt = prompts.drillPrompt(index(), selected, count, context, DEFAULT_WEAKNESS);
        return practice.stream(principal.id(), null, prompt);
    }

    @PostMapping(value = "/practice/reading", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter reading(@RequestBody(required = false) ReadingRequest req,
                              @AuthenticationPrincipal UserPrincipal principal) {
        String selected = req != null ? req.selectedWord() : null;
        String format = req != null && req.format() != null ? req.format() : "part6";
        String context = req != null && req.context() != null ? req.context() : DEFAULT_CONTEXT;
        String prompt = prompts.readingPrompt(index(), selected, format, context, DEFAULT_WEAKNESS);
        return practice.stream(principal.id(), null, prompt);
    }

    @PostMapping(value = "/practice/article", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter article(@RequestBody(required = false) GenRequest req,
                              @AuthenticationPrincipal UserPrincipal principal) {
        String selected = req != null ? req.selectedWord() : null;
        String context = req != null && req.context() != null ? req.context() : DEFAULT_CONTEXT;
        String prompt = prompts.articlePrompt(index(), selected, context, DEFAULT_WEAKNESS);
        return practice.stream(principal.id(), null, prompt);
    }

    @PostMapping(value = "/practice/speaking", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter speaking(@RequestBody(required = false) GenRequest req,
                               @AuthenticationPrincipal UserPrincipal principal) {
        String selected = req != null ? req.selectedWord() : null;
        String context = req != null && req.context() != null ? req.context() : DEFAULT_CONTEXT;
        String prompt = prompts.speakingPrompt(index(), selected, context, DEFAULT_WEAKNESS);
        return practice.stream(principal.id(), null, prompt);
    }

    @PostMapping(value = "/agent/chat", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter chat(@RequestBody ChatRequest req, @AuthenticationPrincipal UserPrincipal principal) {
        String message = req == null || req.message() == null ? "" : req.message();
        return practice.stream(principal.id(), prompts.assistantSystemPrompt(), message);
    }

    private List<String> index() {
        return practice.vocabularyIndex(INDEX_LIMIT);
    }
}
