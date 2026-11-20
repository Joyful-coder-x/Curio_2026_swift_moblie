"""Run with python3 check_model.py. Local constraint checks only."""
from pathlib import Path
import sqlite3

db = sqlite3.connect(':memory:')
db.executescript(Path(__file__).with_name('model.sql').read_text())
def reject(sql, args=()):
    try:
        db.execute(sql, args)
    except sqlite3.IntegrityError:
        return
    raise AssertionError(f'Unexpected success: {sql}')

db.executemany('INSERT INTO tester VALUES (?)', [(x,) for x in 'abcdefghij'])
db.execute("INSERT INTO follows VALUES ('b','a')")
post = 'INSERT INTO thread(id,creator_uid,prompt,published_at,expires_at) VALUES (?,?,?,?,?)'
photo = 'INSERT INTO contribution VALUES (?,?,?,?,?)'
chat = 'INSERT INTO message VALUES (?,?,?,?,?)'
db.execute(post, ('t','a','Find something yellow',0,600))
db.execute(photo, ('t','a',1,'a.jpg',0))
reject(post, ('another','a','Another prompt',1,601))
reject(photo, ('t','a',2,'repeat.jpg',1))
reject(chat, ('t','visitor','m','hello',1))
for slot in range(2,10):
    db.execute(photo, ('t',str(slot),slot,f'{slot}.jpg',2))
reject(photo, ('t','late',10,'ten.jpg',3))
reject(photo, ('t','late',9,'nine.jpg',3))
db.execute(chat, ('t','2','m','Still here',599))
reject(chat, ('t','2','m2','Too late',600))
reject("UPDATE contribution SET asset_path='new.jpg' WHERE uid='a'")
reject("DELETE FROM contribution WHERE uid='a'")
db.execute(post, ('partial','b','Still open?',0,600))
db.execute(photo, ('partial','b',1,'b.jpg',0))
reject(photo, ('partial','visitor',2,'late.jpg',600))
assert db.execute("SELECT count(*) FROM contribution WHERE thread_id='t'").fetchone()==(9,)
assert db.execute("SELECT count(*) FROM message WHERE thread_id='t'").fetchone()==(1,)
print('PASS: daily publication, creator slot, unique contributors, capacity, immutable contributions, member chat and expiry.')

assert {row[0] for row in db.execute("SELECT uid FROM delivery WHERE thread_id='t'")} == set('bcdefghij')
db.execute("INSERT INTO thread VALUES ('private','a','Test',86400,87000,'private')")
assert db.execute("SELECT uid FROM delivery WHERE thread_id='private'").fetchall() == [('b',)]
print('PASS: ten-account public and follower delivery fixtures.')
readers = "SELECT uid FROM readable_thread WHERE thread_id='private'"
assert set(db.execute(readers)) == {('a',), ('b',)}
db.execute("INSERT INTO link_grant VALUES ('private','j')")
assert set(db.execute(readers)) == {('a',), ('b',), ('j',)}
reject(chat, ('private','j','m','View only',86401))
print('PASS: private read before/after link grant; link viewer cannot chat.')
