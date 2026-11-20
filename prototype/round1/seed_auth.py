"""Seed local-only Firebase Auth emulator test users. Run while emulator is running."""
import json
from urllib.error import HTTPError
from urllib.request import Request, urlopen

BASE = 'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:'
def call(action, data):
    req = Request(BASE + action + '?key=local-demo', data=json.dumps(data).encode(),
                  headers={'Content-Type': 'application/json'})
    with urlopen(req, timeout=5) as result:
        return json.load(result)

if __name__ == '__main__':
    for letter in 'abcdefghij':
        data = dict(email=f'curio-{letter}@example.test', password='local-test-only', returnSecureToken=True)
        try:
            result = call('signUp', data)
        except HTTPError as err:
            if json.load(err)['error']['message'] != 'EMAIL_EXISTS':
                raise
            result = call('signInWithPassword', data)
        print(letter.upper(), data['email'], result['localId'])
