CREATE TABLE countdowns (
    id TEXT PRIMARY KEY NOT NULL,
    sort_index INTEGER NOT NULL UNIQUE,
    title TEXT NOT NULL,
    target_date REAL NOT NULL,
    created_at REAL,
    note TEXT NOT NULL,
    symbol TEXT NOT NULL,
    theme TEXT NOT NULL,
    is_completed INTEGER NOT NULL CHECK (is_completed IN (0, 1)),
    completed_at REAL,
    is_pinned INTEGER NOT NULL CHECK (is_pinned IN (0, 1)),
    soon_threshold INTEGER NOT NULL,
    hurry_threshold INTEGER NOT NULL,
    almost_threshold INTEGER NOT NULL,
    attention_enabled INTEGER NOT NULL CHECK (attention_enabled IN (0, 1)),
    is_widget_visible INTEGER NOT NULL CHECK (is_widget_visible IN (0, 1))
);
PRAGMA user_version = 1;
INSERT INTO countdowns (id, sort_index, title, target_date, created_at, note, symbol, theme, is_completed, completed_at, is_pinned, soon_threshold, hurry_threshold, almost_threshold, attention_enabled, is_widget_visible)
VALUES ('11111111-1111-1111-1111-111111111111', 0, 'Fixture Legacy', 0, NULL, 'Synthetic fixture', 'star', 'Ocean Light', 0, NULL, 0, 14, 7, 3, 1, 1);
