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

post = 'INSERT INTO thread VALUES (?,?,?,?,?)'
photo = 'INSERT INTO contribution VALUES (?,?,?,?,?)'
chat = 'INSERT INTO message VALUES (?,?,?,?,?)'
db.execute(post, ('t','a','Find something yellow',0,43200))
db.execute(photo, ('t','a',1,'a.jpg',0))
reject(post, ('another','a','Another prompt',1,43201))
reject(photo, ('t','a',2,'repeat.jpg',1))
reject(chat, ('t','visitor','m','hello',1))
for slot in range(2,10):
    db.execute(photo, ('t',str(slot),slot,f'{slot}.jpg',2))
reject(photo, ('t','late',10,'ten.jpg',3))
reject(photo, ('t','late',9,'nine.jpg',3))
db.execute(chat, ('t','2','m','Still here',43199))
reject(chat, ('t','2','m2','Too late',43200))
reject("UPDATE contribution SET asset_path='new.jpg' WHERE uid='a'")
reject("DELETE FROM contribution WHERE uid='a'")
db.execute(post, ('partial','b','Still open?',0,43200))
db.execute(photo, ('partial','b',1,'b.jpg',0))
reject(photo, ('partial','visitor',2,'late.jpg',43200))
assert db.execute("SELECT count(*) FROM contribution WHERE thread_id='t'").fetchone()==(9,)
assert db.execute("SELECT count(*) FROM message WHERE thread_id='t'").fetchone()==(1,)
print('PASS: daily publication, creator slot, unique contributors, capacity, immutable contributions, member chat and expiry.')
