-- Voca v2 initial schema.
-- One backend owns everything: end-user domain + SRS + third-party API management.

-- ---------- End-user identity ----------
CREATE TABLE users (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email         TEXT NOT NULL UNIQUE,
    password_hash TEXT,
    display_name  TEXT,
    is_admin      BOOLEAN NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE refresh_tokens (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id    BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token      TEXT NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_refresh_tokens_user ON refresh_tokens(user_id);

-- ---------- Decks & cards ----------
CREATE TABLE decks (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    owner_id   BIGINT REFERENCES users(id) ON DELETE SET NULL,
    name       TEXT NOT NULL,
    is_public  BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE deck_members (
    id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    deck_id BIGINT NOT NULL REFERENCES decks(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role    TEXT NOT NULL DEFAULT 'viewer',
    UNIQUE (deck_id, user_id)
);

CREATE TABLE cards (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    deck_id         BIGINT REFERENCES decks(id) ON DELETE SET NULL,
    word            TEXT NOT NULL,
    slug            TEXT NOT NULL UNIQUE,
    ipa             TEXT,
    pronunciation   TEXT,
    frequency       TEXT,
    meaning_en      TEXT,
    meaning_vi      TEXT,
    examples        JSONB NOT NULL DEFAULT '[]',
    use_cases       JSONB NOT NULL DEFAULT '[]',
    memory_tip      TEXT,
    toeic_trap      TEXT,
    part_of_speech  TEXT NOT NULL DEFAULT 'unknown',
    topic           TEXT NOT NULL DEFAULT 'uncategorized',
    tags            JSONB NOT NULL DEFAULT '[]',
    keyword         TEXT,
    practice_prompt TEXT,
    answer          TEXT,
    level           TEXT NOT NULL DEFAULT 'new',   -- default/legacy level; per-user SRS lives in card_review_states
    audio_key       TEXT,                          -- object-storage key (no PNG in v2)
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_cards_word_lower ON cards (lower(word));

-- ---------- SRS (FSRS) ----------
-- Per user x card review state + append-only review log (the signal v1 threw away).
CREATE TABLE card_review_states (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id     BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    card_id     BIGINT NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
    stability   DOUBLE PRECISION,
    difficulty  DOUBLE PRECISION,
    due         TIMESTAMPTZ,
    state       SMALLINT NOT NULL DEFAULT 0,    -- 0 new,1 learning,2 review,3 relearning
    reps        INT NOT NULL DEFAULT 0,
    lapses      INT NOT NULL DEFAULT 0,
    last_review TIMESTAMPTZ,
    UNIQUE (user_id, card_id)
);
CREATE INDEX idx_review_states_due ON card_review_states (user_id, due);

CREATE TABLE review_logs (
    id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id        BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    card_id        BIGINT NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
    rating         SMALLINT NOT NULL,           -- 1 again,2 hard,3 good,4 easy
    state          SMALLINT,
    elapsed_days   INT,
    scheduled_days INT,
    reviewed_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_review_logs_user_card ON review_logs (user_id, card_id);

CREATE TABLE practice_attempts (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id    BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    mode       TEXT NOT NULL,                   -- drills | reading | article | conversation | speaking
    card_id    BIGINT REFERENCES cards(id) ON DELETE SET NULL,
    correct    BOOLEAN,
    payload    JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_practice_attempts_user ON practice_attempts (user_id, created_at);

-- ---------- Per-user server-held secrets/settings ----------
CREATE TABLE user_settings (
    user_id          BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    llm_base_url     TEXT,
    llm_api_key_enc  TEXT,                       -- secret, never returned to clients
    llm_model        TEXT,
    tts_base_url     TEXT,
    tts_api_key_enc  TEXT,                       -- secret, never returned to clients
    tts_model        TEXT,
    voices           JSONB,
    feature_flags    JSONB,
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ================= Third-party API management (priority #1) =================
-- External systems (bilingual-app, other apps) call /v1/* using API keys.

CREATE TABLE api_clients (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name          TEXT NOT NULL,
    description   TEXT,
    owner_user_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
    contact_email TEXT,
    status        TEXT NOT NULL DEFAULT 'active',  -- active | suspended
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE api_keys (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    client_id    BIGINT NOT NULL REFERENCES api_clients(id) ON DELETE CASCADE,
    name         TEXT,
    key_prefix   TEXT NOT NULL,                   -- e.g. "voca_ab12cd34" (for display)
    key_hash     TEXT NOT NULL UNIQUE,            -- SHA-256 of the full plaintext key
    scopes       TEXT NOT NULL DEFAULT '',        -- space-separated: "cards:read audio:read"
    status       TEXT NOT NULL DEFAULT 'active',  -- active | revoked
    expires_at   TIMESTAMPTZ,
    last_used_at TIMESTAMPTZ,
    revoked_at   TIMESTAMPTZ,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_api_keys_client ON api_keys (client_id);

CREATE TABLE api_request_logs (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    api_key_id BIGINT REFERENCES api_keys(id) ON DELETE SET NULL,
    method     TEXT,
    path       TEXT,
    status     INT,
    ip         TEXT,
    at         TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_api_request_logs_key ON api_request_logs (api_key_id, at);
