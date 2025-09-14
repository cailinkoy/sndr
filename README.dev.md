# SNDR 🎁

AI-powered gift ideas and reminders for the people you care about.  
Built with **Flutter/Dart** (client) and **Firebase Functions (Node/TS)** (backend).

---

## ✨ Status
- ✅ Core tabs (Upcoming, Calendar, By Contact)
- ✅ Local notifications & reminder scheduling
- ✅ Gift ideas service wired up (with Amazon affiliate tag)
- ✅ Backend returns non-empty ideas (with fallback)
- 🚧 Fixing analyzer warnings / async gap usage
- 🚧 UI polish (month headers, drawer tweaks)

---

## 🗺️ Roadmap

### Pre-Beta (Family & Friends)
- [x] Clear analyzer warnings
- [ ] Edge-case handling (no contacts, no birthdays, denied permissions)
- [ ] Confirm local fallback gift ideas display if backend fails
- [ ] Finish month header styling + UI nits
- [ ] Prepare builds for TestFlight (iOS) / Play Console (Android)
- [ ] App icon
- [ ] Wrapper error in sheet
- [ ] Links to AI ideas in page
- [ ] Links directly to ideas vs. search links

### Post-Beta (Public Preview)
- [ ] In-app feedback flow
- [ ] Expanded gift idea categories + wow factor scoring
- [ ] Gift lists for occasions/group contacts into gift lists (e.g. Christmas) [Premium]
- [ ] Checking off acquired gifts 
- [ ] Custom adding contacts / overrides for contacts without photos in-app that "stick", if users don't want to sync, notes, etc
- [ ] Easily adding gift ideas from contact or from AI idea with seamless flow [Premium]
- [ ] Polished empty states / onboarding
- [ ] Basic analytics & error logging
- [ ] Make the carat on the Contacts tab take you to a devoted page for that contact and managing their gifts
- [ ] Affiliate integrations beyond Amazon (Rakuten, ShareASale, Uncommon Goods)
- [ ] Google auth/sync [Premium]

---

## 🛠️ Running Locally

### Flutter client
```bash
flutter pub get
flutter run

### Backend

Edit functions/src/index.ts and deploy with:

firebase deploy --only functions:giftIdeas


Curl test (use cmd.exe or Git Bash on Windows, not PowerShell):

curl -i -s -X POST "https://us-central1-skilful-reducer-385816.cloudfunctions.net/giftIdeas" \
  -H "Content-Type: application/json" \
  -d "{\"occasion\":\"Birthday\",\"budget\":\"$25-$100\",\"recipient\":{\"name\":\"Abby Smith\"},\"locale\":\"en-US\"}"


Expected: X-GiftIdeas-Handler header + non-empty ideas list.

🎯 Vision

SNDR helps you never miss an occasion and always have thoughtful, AI-curated gift ideas — delivered with affiliate links so you can act instantly.

📌 Notes

Client is Flutter/Dart.

Backend: Firebase Functions v2, Node 20, OpenAI Responses API.

Amazon affiliate tag: sassydove00-20.

Interests optional/empty for now.