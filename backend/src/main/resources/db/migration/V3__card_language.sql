ALTER TABLE cards
    ADD COLUMN language VARCHAR(16) NOT NULL DEFAULT 'en';

CREATE INDEX idx_cards_owner_language ON cards (owner_id, language);
