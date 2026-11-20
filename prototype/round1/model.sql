-- SQLite reference for the prototype data relationships. Timestamps are UTC epoch seconds.
PRAGMA foreign_keys = ON;
CREATE TABLE thread (
  id TEXT PRIMARY KEY NOT NULL, creator_uid TEXT NOT NULL, prompt TEXT NOT NULL CHECK(length(trim(prompt)) > 0),
  published_at INTEGER NOT NULL, expires_at INTEGER NOT NULL CHECK(expires_at = published_at + 43200),
  UNIQUE(creator_uid, published_at)
);
CREATE UNIQUE INDEX one_daily ON thread(creator_uid, date(published_at,'unixepoch'));
CREATE TABLE contribution (
  thread_id TEXT NOT NULL REFERENCES thread(id), uid TEXT NOT NULL,
  slot INTEGER NOT NULL CHECK(slot BETWEEN 1 AND 9), asset_path TEXT NOT NULL UNIQUE,
  accepted_at INTEGER NOT NULL, PRIMARY KEY(thread_id,uid), UNIQUE(thread_id,slot)
);
CREATE TRIGGER check_contribution BEFORE INSERT ON contribution BEGIN
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM thread WHERE id=NEW.thread_id AND NEW.accepted_at>=published_at
    AND NEW.accepted_at<expires_at AND ((NEW.slot=1)=(NEW.uid=creator_uid))
  ) THEN RAISE(ABORT,'ineligible contribution') END;
END;
CREATE TRIGGER immutable_update BEFORE UPDATE ON contribution BEGIN SELECT RAISE(ABORT,'immutable'); END;
CREATE TRIGGER immutable_delete BEFORE DELETE ON contribution BEGIN SELECT RAISE(ABORT,'immutable'); END;
CREATE TABLE message (
  thread_id TEXT NOT NULL, sender_uid TEXT NOT NULL, request_id TEXT NOT NULL,
  body TEXT NOT NULL CHECK(length(trim(body))>0), sent_at INTEGER NOT NULL,
  PRIMARY KEY(thread_id,sender_uid,request_id),
  FOREIGN KEY(thread_id,sender_uid) REFERENCES contribution(thread_id,uid)
);
CREATE TRIGGER check_message BEFORE INSERT ON message BEGIN
  SELECT CASE WHEN NOT EXISTS (
    SELECT 1 FROM thread WHERE id=NEW.thread_id AND NEW.sent_at<expires_at AND NEW.sent_at >=
    (SELECT accepted_at FROM contribution WHERE thread_id=NEW.thread_id AND uid=NEW.sender_uid)
  ) THEN RAISE(ABORT,'chat unavailable') END;
END;
