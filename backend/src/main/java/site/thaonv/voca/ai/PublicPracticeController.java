package site.thaonv.voca.ai;

import org.springframework.http.MediaType;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import site.thaonv.voca.apikey.ApiKeyPrincipal;

/** Third-party streaming practice generators (API key with scope practice:generate). */
@RestController
@RequestMapping("/v1/practice")
public class PublicPracticeController {

    private final PracticeService practice;
    private final PracticePrompts prompts;

    public PublicPracticeController(PracticeService practice, PracticePrompts prompts) {
        this.practice = practice;
        this.prompts = prompts;
    }

    @PostMapping(value = "/drills", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    @PreAuthorize("hasAuthority('SCOPE_practice:generate')")
    public SseEmitter drills(@RequestBody(required = false) PracticeController.DrillRequest req,
                             @AuthenticationPrincipal ApiKeyPrincipal principal) {
        Long ownerId = ApiKeyPrincipal.requireOwner(principal);
        int rawCount = req != null && req.count() != null ? req.count() : 5;
        int count = Math.max(1, Math.min(20, rawCount));
        String selected = req != null ? req.selectedWord() : null;
        String context = req != null && req.context() != null ? req.context() : "All words";
        String language = req != null ? req.language() : null;
        String prompt = prompts.drillPrompt(practice.vocabularyIndex(ownerId, language, 60), selected, count, context,
                "No recorded practice mistakes yet.", language);
        return practice.stream(ownerId, null, prompt);
    }

    @PostMapping(value = "/reading", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    @PreAuthorize("hasAuthority('SCOPE_practice:generate')")
    public SseEmitter reading(@RequestBody(required = false) PracticeController.ReadingRequest req,
                              @AuthenticationPrincipal ApiKeyPrincipal principal) {
        Long ownerId = ApiKeyPrincipal.requireOwner(principal);
        String selected = req != null ? req.selectedWord() : null;
        String format = req != null && req.format() != null ? req.format() : "part6";
        String context = req != null && req.context() != null ? req.context() : "All words";
        String language = req != null ? req.language() : null;
        String prompt = prompts.readingPrompt(practice.vocabularyIndex(ownerId, language, 60), selected, format, context,
                "No recorded practice mistakes yet.", language);
        return practice.stream(ownerId, null, prompt);
    }
}
