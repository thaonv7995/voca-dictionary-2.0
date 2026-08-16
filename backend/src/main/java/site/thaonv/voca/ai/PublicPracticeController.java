package site.thaonv.voca.ai;

import org.springframework.http.MediaType;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

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
    public SseEmitter drills(@RequestBody(required = false) PracticeController.DrillRequest req) {
        int count = req != null && req.count() != null ? req.count() : 5;
        String selected = req != null ? req.selectedWord() : null;
        String prompt = prompts.drillPrompt(practice.vocabularyIndex(60), selected, count, "All words",
                "No recorded practice mistakes yet.");
        return practice.stream(null, null, prompt);
    }

    @PostMapping(value = "/reading", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    @PreAuthorize("hasAuthority('SCOPE_practice:generate')")
    public SseEmitter reading(@RequestBody(required = false) PracticeController.ReadingRequest req) {
        String selected = req != null ? req.selectedWord() : null;
        String format = req != null && req.format() != null ? req.format() : "part6";
        String prompt = prompts.readingPrompt(practice.vocabularyIndex(60), selected, format, "All words",
                "No recorded practice mistakes yet.");
        return practice.stream(null, null, prompt);
    }
}
