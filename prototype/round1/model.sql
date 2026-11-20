-- SQLite reference for the prototype data relationships. Timestamps are UTC epoch seconds.
PRAGMA foreign_keys = ON;
CREATE TABLE thread (
  id TEXT PRIMARY KEY NOT NULL, creator_uid TEXT NOT NULL, prompt TEXT NOT NULL CHECK(length(trim(prompt)) > 0),
  published_at INTEGER NOT NULL, expires_at INTEGER NOT NULL CHECK(expires_at = published_at + 600),
  visibility TEXT NOT NULL DEFAULT 'public' CHECK(visibility IN ('public','private')),
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

-- Round-one distribution fixture. Register testers first; one row per recipient and post.
CREATE TABLE tester(uid TEXT PRIMARY KEY NOT NULL);
CREATE TABLE follows(follower TEXT REFERENCES tester(uid), author TEXT REFERENCES tester(uid), PRIMARY KEY(follower,author));
CREATE TABLE delivery(thread_id TEXT REFERENCES thread(id), uid TEXT REFERENCES tester(uid), PRIMARY KEY(thread_id,uid));
CREATE TRIGGER distribute AFTER INSERT ON thread BEGIN
  INSERT INTO delivery SELECT NEW.id, uid FROM tester
  WHERE uid <> NEW.creator_uid AND (NEW.visibility='public' OR EXISTS
    (SELECT 1 FROM follows WHERE follower=uid AND author=NEW.creator_uid));
END;
-- Signed-in caller's materialized link grant after server-side token redemption.
CREATE TABLE link_grant(thread_id TEXT REFERENCES thread(id), uid TEXT REFERENCES tester(uid), PRIMARY KEY(thread_id,uid));
CREATE VIEW readable_thread AS
SELECT t.id AS thread_id,u.uid FROM thread t CROSS JOIN tester u
WHERE t.visibility='public' OR t.creator_uid=u.uid
OR EXISTS(SELECT 1 FROM follows f WHERE f.author=t.creator_uid AND f.follower=u.uid)
OR EXISTS(SELECT 1 FROM link_grant g WHERE g.thread_id=t.id AND g.uid=u.uid)
OR EXISTS(SELECT 1 FROM contribution c WHERE c.thread_id=t.id AND c.uid=u.uid);
