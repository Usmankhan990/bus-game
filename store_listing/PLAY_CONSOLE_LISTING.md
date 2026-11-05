# Play Console ke liye saara maal: Bus Jam Party

Play Console mein jo field jahan hai, wahan se copy-paste karein. Text English mein hai
(Play Store par yahi dikhega), samjhane wali baatein Roman Urdu mein.

## Files (sab isi `store_listing` folder mein)

| File | Play Console mein kahan |
|---|---|
| `icon_512.png` | Grow → Store presence → Main store listing → **App icon** |
| `feature_graphic_1024x500.png` | Wahi page → **Feature graphic** |
| `screenshots/1_home.png` … `5_play_tilted.png` (5 files) | Wahi page → **Phone screenshots** (isi tarteeb se) |
| `privacy_policy.html` | Website par upload karein, phir link: Policy → App content → **Privacy policy** |
| `app-ads.txt` | Website ke root par upload karein (AdMob ke liye) |
| `build/app/outputs/bundle/release/app-release.aab` | Test and release → **Create new release** |

Screenshots aur feature graphic dobara banane hon: `tool/make_store_listing.dart` (andar tareeqa likha hai).
Icon dobara banana ho: `flutter test tool/make_app_icon.dart`.

---

## 1) App details

| Field | Kya likhna hai |
|---|---|
| **App name** (30 haroof tak) | `Bus Jam Party - Parking Puzzle` |
| Default language | English (United States) – en-US |
| App or game | **Game** |
| Free or paid | **Free** |
| Category | **Puzzle** |
| Tags | Puzzle, Casual, Logic, Brain games |
| **Developer name** (Play Console account banate waqt) | `CodedHouse` |
| Contact email | Apna email (yeh Play Store par sab ko dikhta hai) |
| Website | GitHub Pages wala link (neeche section 7) |

## 2) Short description (80 haroof tak)

```
Tap cars & buses to clear the parking jam and get every passenger on board!
```

## 3) Full description (4000 haroof tak)

```
Get ready for the most colorful traffic jam in town! 🚌🚗

Bus Jam Party is a relaxing yet brainy parking puzzle. The lot is packed with cars, vans and long buses – and a big crowd of passengers is waiting at the bus stop. Every vehicle can only drive the way its arrow points. Tap a vehicle with a clear road and watch it drive out to the stop, where passengers of the same color hop on board. When every seat is full, off it goes!

Sounds easy? The stop has only a few parking spots. Pick the wrong vehicle and the spots fill up fast. Think ahead, choose the right color at the right time and clear the whole jam!

🧩 HOW TO PLAY
• Tap a car, van or bus whose road is clear
• It drives to a free parking spot at the bus stop
• Passengers board the vehicle of their own color
• Full vehicles drive away and free the spot
• Get every passenger on board to win the level!

⭐ FEATURES
• Hundreds of fun levels that get smarter as you go
• Cars (4 seats), vans (6 seats) and long buses (10 seats)
• Simple one-tap controls – easy to learn, hard to put down
• HARD and SUPER HARD levels for real puzzle fans
• Relaxing "breather" levels to catch your breath
• Unlock extra parking spots when the stop gets crowded
• Helpful boosters: VIP spot, Sort the crowd and Shuffle colors
• Daily bonus, lucky spin, free coins and check-in gifts
• Bright 3D cartoon graphics and cheerful sounds
• Play offline – no internet needed to play
• Your progress is saved automatically

Perfect for a quick break or a long puzzle session. Can you clear every jam?

Download Bus Jam Party now and start tapping! 🎉
```

## 4) Release notes ("What's new"), har release mein

```
• Brand new 3D cars, vans and buses
• Smoother, tidier passenger crowds
• Fresh splash screen and app icon
• New tidy parking lot layouts
• Bug fixes and performance improvements
```

## 5) App content (Policy section) – jawab

| Sawal | Jawab |
|---|---|
| Privacy policy | Website par `privacy_policy.html` ka link |
| Ads – Does your app contain ads? | **Yes** |
| App access | **All functionality is available without special access** |
| Target audience | **13–15, 16–17, 18 and over**. 13 se kam umar wali koi bhi category **na** chunein: bachon wali category mein ads ke qawaid bohot sakht hain. |
| Appeal to children? | **No** |
| Content rating questionnaire | Category **Game**. Violence, Fear, Sexuality, Language, Drugs, Gambling, User interaction/chat, Shares location: sab **No**. Digital purchases: **No**. Nateeja aam taur par "Everyone / PEGI 3" aata hai. |
| Advertising ID | **Yes** → Purpose: **Advertising or marketing**, **Analytics** |
| Government / Financial / Health / News app | **No** |
| In-app purchases | **No** (abhi shop "Coming soon" hai) |

## 6) Data safety form – jawab (AdMob ki wajah se)

Game khud koi personal data jama nahi karta, lekin Google AdMob ads ke liye kuch data leta
hai. Is liye form mein yeh batana zaroori hai:

- Does your app collect or share any of the required user data types? → **Yes**
- Is all of the user data collected by your app encrypted in transit? → **Yes**
- Do you provide a way for users to request that their data is deleted? → **No** (game koi account nahi banata)

| Data type | Collected | Shared | Purpose | Required/Optional |
|---|---|---|---|---|
| Location → **Approximate location** | Yes | Yes | Advertising or marketing, Analytics, Fraud prevention | Required |
| App activity → **App interactions** | Yes | Yes | Advertising or marketing, Analytics | Required |
| App info and performance → **Crash logs**, **Diagnostics** | Yes | Yes | Analytics | Required |
| Device or other IDs → **Device or other IDs** | Yes | Yes | Advertising or marketing, Analytics, Fraud prevention | Required |

- Is this data processed ephemerally? → **No**
- Google ki apni guide (form bharne se pehle zaroor dekhein, yeh badalti rehti hai):
  https://developers.google.com/admob/android/privacy/play-data-disclosure

## 7) Website: privacy policy aur app-ads.txt (free, GitHub Pages)

1. github.com par free account banayein.
2. Naya repository banayein, naam bilkul yeh: `apnausername.github.io`. Ise **Public** rakhein.
3. "Add file → Upload files" dabayein aur `privacy_policy.html` aur `app-ads.txt` upload karein.
   Upload se pehle `privacy_policy.html` mein `YOUR_EMAIL_HERE` ki jagah apna email likhein.
4. 5–10 minute baad yeh links chalne lagenge:
   - `https://apnausername.github.io/privacy_policy.html` → Play Console mein privacy policy
   - `https://apnausername.github.io/app-ads.txt` → AdMob ke liye
5. Play Console → Store settings → **Website** mein `https://apnausername.github.io` likhein
   (yeh wahi domain hona chahiye jahan `app-ads.txt` hai).

## 8) AdMob mein zaroori kaam

1. AdMob → Apps → app ko Play Store wali app se **link** karein (app live hone ke baad).
2. **Blocking controls** → Sensitive categories: Alcohol, Gambling, Dating waghera block karein.
3. **Privacy & messaging** → GDPR message banayein (Europe ke users ke liye).
4. **Settings → Test devices** mein apna phone add karein. Apne ads par kabhi click na karein.

## 9) Closed testing (naye account ke liye: 12 testers, 14 din)

1. Test and release → Testing → **Closed testing** → Create track. Testers ki email list banayein (kam az kam 12).
2. **Create new release** → AAB upload karein → "What's new" (upar section 4) paste karein.
3. Countries chunein → **Review release** → **Start rollout**.
4. Testers ko "opt-in link" bhejein. Har tester link khol kar "Become a tester" dabaye, phir Play Store se game install kare.
5. 12 testers ko lagatar 14 din test karna zaroori hai. Us ke baad **Production** ke liye apply karein.
