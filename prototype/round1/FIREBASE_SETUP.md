# Curio round-one Firebase setup

The SwiftUI target currently runs in **simulator demo mode**. Its A–J switcher and sample
photos make the four-screen product flow testable without a cloud account.

## Start the local emulators

Install Node.js 22 and run these commands from \`prototype/round1\`:

    npm install --prefix functions
    npx firebase-tools emulators:start --project curio-round1-local

In a second terminal:

    python3 seed_auth.py

The emulator UI is at \`http://127.0.0.1:4000\`. Auth, Functions, Firestore, and Storage use
ports 9099, 5001, 8080, and 9199.

## Connect the iOS target locally

Link \`FirebaseAuth\`, \`FirebaseFirestore\`, \`FirebaseFunctions\`, and \`FirebaseStorage\`
from the existing firebase-ios-sdk package reference. In Debug configuration, route them to:

    Auth.auth().useEmulator(withHost: "127.0.0.1", port: 9099)
    Firestore.firestore().useEmulator(withHost: "127.0.0.1", port: 8080)
    Functions.functions().useEmulator(withHost: "127.0.0.1", port: 5001)
    Storage.storage().useEmulator(withHost: "127.0.0.1", port: 9199)

Use \`127.0.0.1\` for the iOS Simulator. A physical iPhone cannot use its own loopback
address to reach the Mac; use the Mac's LAN hostname or IP and allow the firewall connection.

## Next step: online Firebase and real iPhones

1. Create separate Firebase development and production projects.
2. Register the iOS bundle ID and add the correct \`GoogleService-Info.plist\` per build
   configuration. Do not commit private service-account credentials.
3. Remove emulator routing from non-Debug builds. Select configuration through build settings,
   not hard-coded SwiftUI view code.
4. Deploy the rules, indexes, and Functions to the development project first.
5. Enable Email/Password Auth and create independent users. Remove the A–J password and
   simulator account switcher from release builds.
6. Test two real iPhones signed into different accounts. Firestore listeners provide
   foreground real-time updates; add APNs/FCM later for background notifications.
7. Add App Check, rate limits, production logging, image validation, and privacy-aware account
   deletion/export before public release.

Before online deployment, complete \`preparePhoto\`, immutable Storage generation validation,
private viewer/link grants, delivery fan-out, the UTC daily publication guard, cleanup, and
all emulator acceptance tests in \`START_HERE.md\`. Admin SDK operations bypass client rules,
so every invariant must also be enforced inside each callable.
