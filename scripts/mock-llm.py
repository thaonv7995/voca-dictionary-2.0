#!/usr/bin/env python3
"""OpenAI-compatible mock LLM for local E2E testing of Voca.

Serves:
  POST /v1/chat/completions  — stream=true → SSE deltas (small chunks, word-boundary
                               spaces preserved, newlines inside NDJSON), stream=false → JSON.
  POST /v1/audio/speech      — tiny silent MP3 bytes.

Content is chosen by keywords in the prompt (mirrors PracticePrompts/ClientPrompts):
  "Return NDJSON"        → drills (3 objects)
  "reading_context"      → TOEIC Part 6 reading JSON
  "article_practice"     → article JSON
  "speaking_practice"    → speaking JSON
  "daily_conversation"   → conversation JSON
  otherwise              → long Vietnamese/English markdown-ish chat reply
"""
import json, re, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

DRILLS = "\n".join(json.dumps(o, ensure_ascii=False) for o in [
  {"kind":"collocation","trapType":"wrong_preposition","targetWord":"allocate","testedSkill":"prepositional collocation","difficulty":"medium",
   "title":"Budget Deadline","instruction":"Choose the correct phrase to complete the sentence.",
   "scenario":"All department heads must submit their quarterly budgets ______ the board meeting on Friday.",
   "choices":["prior of","prior to","prior for","prior than"],"answer":"prior to",
   "explanation":"'Prior to' means before. — 'Prior to' nghĩa là trước khi.",
   "whyWrong":{"prior of":"Not a valid collocation — không tồn tại.","prior for":"Wrong preposition — sai giới từ.","prior than":"Confused with 'other than' — nhầm cấu trúc."}},
  {"kind":"scenario","trapType":"near_synonym_wrong_context","targetWord":"diligent","testedSkill":"adjective choice","difficulty":"easy",
   "title":"Performance Review","instruction":"Pick the word that best fits the context.",
   "scenario":"Maria is praised for being extremely ______; she never misses a deadline and double-checks every report.",
   "choices":["diligent","urgent","frequent","adjacent"],"answer":"diligent",
   "explanation":"'Diligent' describes careful, persistent work. — 'Diligent' nghĩa là siêng năng.",
   "whyWrong":{"urgent":"Describes tasks, not people — dùng cho việc gấp.","frequent":"Means happening often — nghĩa là thường xuyên.","adjacent":"Means next to — nghĩa là kề bên."}},
  {"kind":"part2_response","trapType":"wrong_question_type","targetWord":"allocate","testedSkill":"listening response","difficulty":"hard",
   "title":"Part 2 Response","instruction":"Choose the best response to the question.",
   "scenario":"Who will allocate the conference rooms for next week's training?",
   "choices":["The facilities team handles that.","Yes, at three o'clock.","It was very prominent."],"answer":"The facilities team handles that.",
   "explanation":"A WHO question needs a person/team answer. — Câu hỏi WHO cần chủ thể.",
   "whyWrong":{"Yes, at three o'clock.":"Answers WHEN, not WHO — trả lời sai loại câu hỏi.","It was very prominent.":"Irrelevant adjective — không liên quan."}}])

READING = json.dumps({
  "type":"reading_context","format":"part6","documentType":"email","title":"Upcoming Market Analysis Project",
  "passage":["Subject: Upcoming Market Analysis Project","Dear Team,",
              "As we prepare for the next fiscal year, we want to [1] _____ the potential of our new analytics platform.",
              "Before we launch the campaign, we must [2] _____ the initial test results carefully to ensure accuracy.",
              "Please submit your feedback by Friday.","Best regards,","Project Management Team"],
  "questions":[
    {"blank":1,"prompt":"Choose the best word to fill in blank [1].","choices":["examine","allocate","retain","neglect"],"answer":"examine",
     "explanation":"'Examine the potential' is the natural collocation. — 'Examine' nghĩa là xem xét."},
    {"blank":2,"prompt":"Choose the best word to fill in blank [2].","choices":["review","assemble","recruit","postpone"],"answer":"review",
     "explanation":"'Review results' is correct. — 'Review' nghĩa là xem lại."}],
  "targetWords":["examine","review","allocate"]}, ensure_ascii=False)

ARTICLE = json.dumps({
  "type":"article_practice","title":"Local Startups Attract Record Investment","documentType":"article",
  "passage":["Small businesses in the region attracted record funding this quarter.",
              "Analysts say investors are eager to allocate capital to firms with diligent management teams.",
              "A prominent example is GreenCart, a delivery startup that doubled revenue in six months.",
              "The company plans to examine several expansion options before year-end.",
              "Economists expect the trend to continue into the next fiscal year."],
  "targetWords":["allocate","diligent","prominent","examine"],
  "questions":[
    {"prompt":"What is the main purpose of the article?","choices":["To report an investment trend","To advertise GreenCart","To criticize local banks","To describe a hiring plan"],
     "answer":"To report an investment trend","explanation":"The article reports funding trends. — Bài báo nói về xu hướng đầu tư."},
    {"prompt":"The word 'prominent' in paragraph 3 is closest in meaning to…","choices":["well-known","profitable","recent","risky"],
     "answer":"well-known","explanation":"'Prominent' ≈ nổi bật, nổi tiếng."}],
  "vocabularyNotes":[
    {"word":"allocate","meaningVi":"phân bổ","contextMeaning":"phân bổ vốn cho các công ty"},
    {"word":"diligent","meaningVi":"siêng năng","contextMeaning":"đội ngũ quản lý tận tâm"}]}, ensure_ascii=False)

SPEAKING = json.dumps({
  "type":"speaking_practice","title":"Quarterly Planning Meeting","topic":"Business",
  "passageText":"Good morning everyone. Today we will examine our quarterly results and allocate resources for the next phase. Our diligent finance team has prepared a prominent summary of the key figures.",
  "sentences":[
    {"text":"Good morning everyone.","ipa":"ɡʊd ˈmɔːrnɪŋ ˈevriwʌn",
     "words":[{"word":"Good","ipa":"ɡʊd","startMs":0,"endMs":300},{"word":"morning","ipa":"ˈmɔːrnɪŋ","startMs":300,"endMs":800},{"word":"everyone","ipa":"ˈevriwʌn","startMs":800,"endMs":1400}],
     "connectedSpeech":[{"from":"Good","to":"morning","type":"linking","symbol":"‿"}]},
    {"text":"Today we will examine our quarterly results.","ipa":"təˈdeɪ wi wɪl ɪɡˈzæmɪn ˈaʊər ˈkwɔːrtərli rɪˈzʌlts",
     "words":[{"word":"Today","ipa":"təˈdeɪ","startMs":1600,"endMs":2000},{"word":"examine","ipa":"ɪɡˈzæmɪn","startMs":2600,"endMs":3200}],
     "connectedSpeech":[]}]}, ensure_ascii=False)

CONVERSATION = json.dumps({
  "type":"daily_conversation","format":"conversation","title":"Planning the Team Offsite",
  "context":"Emma and Brian discuss organising next month's team offsite in the office breakroom.",
  "speakers":["Emma","Brian"],"voiceAssignments":{},
  "lines":[
    {"speaker":"Emma","text":"Brian, did you examine the venue options for the offsite yet?","translation":"Brian, anh đã xem xét các lựa chọn địa điểm cho buổi offsite chưa?","vocabulary":["examine"],"vocabularyMeanings":{"examine":"xem xét"}},
    {"speaker":"Brian","text":"Yes, and I think we should allocate most of the budget to the lakeside resort.","translation":"Rồi, và tôi nghĩ chúng ta nên phân bổ phần lớn ngân sách cho khu nghỉ ven hồ.","vocabulary":["allocate"],"vocabularyMeanings":{"allocate":"phân bổ"}},
    {"speaker":"Emma","text":"Great idea. Their events team has a prominent reputation for being diligent.","translation":"Ý hay đấy. Đội sự kiện của họ nổi tiếng là siêng năng.","vocabulary":["prominent","diligent"],"vocabularyMeanings":{"prominent":"nổi tiếng","diligent":"siêng năng"}},
    {"speaker":"Brian","text":"I'll draft the proposal this afternoon and send it to you for review.","translation":"Chiều nay tôi sẽ soạn đề xuất và gửi chị xem lại.","vocabulary":[],"vocabularyMeanings":{}}]}, ensure_ascii=False)

CHAT = ("Great question! Here is the difference between **diligent** and **hard-working**:\n\n"
        "1. Diligent — careful AND persistent. It emphasises attention to detail. Ví dụ: a diligent auditor double-checks every figure.\n"
        "2. Hard-working — puts in many hours, but not necessarily carefully. Ví dụ: a hard-working courier does long shifts.\n\n"
        "In TOEIC, watch for the trap where 'diligent' is replaced by 'urgent' or 'frequent' — they look plausible but describe tasks, not people. "
        "Tóm lại: 'diligent' nhấn mạnh sự cẩn thận và bền bỉ, còn 'hard-working' chỉ nói về cường độ làm việc. "
        "Hãy thử đặt một câu với 'diligent' về đồng nghiệp của bạn nhé!")

# ~1s of silence, MPEG-1 Layer III frame header repeated (enough for AVAudioPlayer not to choke)
SILENT_MP3 = bytes.fromhex("fffb9064" + "00"*412) * 8

def pick_content(prompt: str) -> str:
    if "Return NDJSON" in prompt or "NDJSON only" in prompt: return DRILLS
    if "reading_context" in prompt: return READING
    if "article_practice" in prompt: return ARTICLE
    if "speaking_practice" in prompt: return SPEAKING
    if "daily_conversation" in prompt: return CONVERSATION
    return CHAT

def tokenize(content: str):
    """Split like an LLM: word-boundary spaces lead the next chunk; newlines kept as chunks."""
    return [t for t in re.findall(r"\n+|\s?[^\s]+", content) if t]

class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    def log_message(self, *a): pass

    def do_POST(self):
        n = int(self.headers.get("Content-Length", 0))
        body = json.loads(self.rfile.read(n) or b"{}")
        if self.path.endswith("/audio/speech"):
            self.send_response(200)
            self.send_header("Content-Type", "audio/mpeg")
            self.send_header("Content-Length", str(len(SILENT_MP3)))
            self.end_headers()
            self.wfile.write(SILENT_MP3)
            return
        if not self.path.endswith("/chat/completions"):
            self.send_response(404); self.send_header("Content-Length","0"); self.end_headers(); return

        prompt = " ".join(str(m.get("content","")) for m in body.get("messages", []))
        content = pick_content(prompt)

        if body.get("stream"):
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Connection", "close")
            self.end_headers()
            for tok in tokenize(content):
                chunk = {"id":"mock","object":"chat.completion.chunk",
                         "choices":[{"index":0,"delta":{"content":tok}}]}
                self.wfile.write(f"data: {json.dumps(chunk, ensure_ascii=False)}\n\n".encode())
                self.wfile.flush()
                time.sleep(0.004)
            self.wfile.write(b"data: [DONE]\n\n")
            self.wfile.flush()
        else:
            resp = json.dumps({"id":"mock","object":"chat.completion",
                               "choices":[{"index":0,"message":{"role":"assistant","content":content}}]},
                              ensure_ascii=False).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(resp)))
            self.end_headers()
            self.wfile.write(resp)

if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", 23000), Handler).serve_forever()
