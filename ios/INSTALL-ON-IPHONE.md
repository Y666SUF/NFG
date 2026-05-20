# Install NFG Crash on your iPhone (Mac/Xcode guide for Windows users)

## Important: one step only YOU can do

Apple requires **your Apple ID password** to install apps on a real iPhone.  
Nobody (including Cursor) can type that for you. It takes about 2 minutes.

---

## Part A — Add Apple ID (use keyboard shortcut)

1. **Click** the Xcode window once (blue icon app).
2. On the Mac, the **menu bar is at the very top of the screen** (next to the  time), **not** inside the Xcode window.
3. Press these keys together: **⌘ Command + ,** (comma)  
   → This opens **Xcode Settings** (like Settings in VS Code).
4. Click **Accounts** at the top of the settings window.
5. Click the **+** button (bottom left) → **Apple ID…**
6. Sign in with your normal iPhone Apple ID and password.

---

## Part B — Turn on signing (still in Xcode)

1. Press **⌘ Command + 0** (zero) if the **left sidebar** is hidden — you should see a folder tree.
2. Click the **blue icon** at the top of that list named **NFGCrash** (the project).
3. In the middle column, under **TARGETS**, click **NFGCrash** (not the project line).
4. Click the **Signing & Capabilities** tab at the top.
5. Turn on **Automatically manage signing**.
6. Open the **Team** dropdown → choose **Your Name (Personal Team)**.

If you see a yellow warning, click **Try Again** or **Enable Development**.

---

## Part C — Run on your iPhone

1. At the **top centre** of Xcode there is a bar showing something like  
   `NFGCrash > iPhone 17 Pro`.
2. Click that bar → pick **Yusuf's iPhone** (your real phone, not "Simulator").
3. Press **⌘ Command + R** (or click the **Play ▶** button on the left of that bar).

Keep the phone **unlocked**. The app will install and open.

---

## If the app won't open on the phone

**Settings → General → VPN & Device Management** → tap your developer profile → **Trust**.

---

## Mac vs Windows quick map

| Windows habit        | On Mac with Xcode        |
|---------------------|---------------------------|
| File menu in app    | Top of **screen** menu bar |
| Settings in app     | **⌘ ,**                   |
| Build / Run         | **⌘ R**                   |
| Show sidebar        | **⌘ 0**                   |
