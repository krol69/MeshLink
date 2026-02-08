# How to Get MeshLink on Your iPhone (No Computer Needed)

Everything below is done from Safari on your iPhone. You never need a Mac, PC, or iPad.

---

## Part 1: Create a GitHub Account (skip if you have one)

1. Open **Safari** on your iPhone
2. Go to **github.com**
3. Tap **Sign up**
4. Enter your email, create a password, pick a username
5. Verify your email (check your inbox, tap the link)
6. Done — you now have a free GitHub account

---

## Part 2: Create the Repository

1. On **github.com**, tap the **+** icon (top right) → **New repository**
2. Repository name: **MeshLink**
3. Make sure **Public** is selected (required for free Actions builds)
4. Check **Add a README file**
5. Tap **Create repository**

---

## Part 3: Upload the Project Files

This is the most tedious part, but you only do it once.

### 3A: Upload the workflow file first

1. In your new repo, tap **Add file** → **Create new file**
2. In the filename box, type exactly: `.github/workflows/build.yml`
   - (typing the `/` automatically creates the folders)
3. Paste the ENTIRE contents of the `build.yml` file into the editor
4. Scroll down, tap **Commit changes** → **Commit changes**

### 3B: Upload project.yml

1. Go back to the repo main page
2. Tap **Add file** → **Create new file**
3. Filename: `project.yml`
4. Paste the contents of `project.yml`
5. Tap **Commit changes** → **Commit changes**

### 3C: Upload each Swift file

Repeat this process for each file. The filename must include the folder path:

| Type this as the filename | Paste contents from |
|---------------------------|-------------------|
| `MeshLink/MeshLinkApp.swift` | MeshLinkApp.swift |
| `MeshLink/Info.plist` | Info.plist |
| `MeshLink/Models/Models.swift` | Models.swift |
| `MeshLink/Services/BLEService.swift` | BLEService.swift |
| `MeshLink/Services/CryptoService.swift` | CryptoService.swift |
| `MeshLink/Services/SoundService.swift` | SoundService.swift |
| `MeshLink/Services/MeshViewModel.swift` | MeshViewModel.swift |
| `MeshLink/Views/SetupView.swift` | SetupView.swift |
| `MeshLink/Views/MainView.swift` | MainView.swift |
| `MeshLink/Views/ChatView.swift` | ChatView.swift |
| `MeshLink/Views/PeersView.swift` | PeersView.swift |
| `MeshLink/Views/LogsView.swift` | LogsView.swift |

For each one:
1. Tap **Add file** → **Create new file**
2. Type the full path as the filename (e.g. `MeshLink/Views/ChatView.swift`)
3. Paste the file contents
4. Tap **Commit changes** → **Commit changes**
5. Go back to repo main page and repeat

### 3D: Upload asset catalog files

| Filename | Contents from |
|----------|--------------|
| `MeshLink/Assets.xcassets/Contents.json` | Assets Contents.json |
| `MeshLink/Assets.xcassets/AccentColor.colorset/Contents.json` | AccentColor Contents.json |
| `MeshLink/Assets.xcassets/AppIcon.appiconset/Contents.json` | AppIcon Contents.json |

Same process — create new file, type the full path, paste, commit.

### EASIER ALTERNATIVE: Use Working Copy app

If you want to skip the manual file-by-file upload:

1. Download **Working Copy** (free) from the App Store
2. Clone your empty MeshLink repo
3. Unzip the `MeshLink-Ready.zip` file I gave you (use the Files app)
4. Copy all files into the Working Copy repo folder
5. Commit and push — all files upload at once

---

## Part 4: Wait for the Build

After your last commit, the build starts automatically.

1. Tap the **Actions** tab in your repo
2. You should see **"Build MeshLink IPA"** running (yellow dot = in progress)
3. Wait about **3-5 minutes** for it to finish
4. Green checkmark = success! Red X = something went wrong

### If the build fails:
- Tap the failed run to see the error log
- Most common issue: a file was pasted incorrectly or a filename was typed wrong
- Double-check each file matches the paths in the table above exactly
- Fix the file and commit — the build will automatically re-run

---

## Part 5: Download Your IPA

1. Tap the green-checkmark build run
2. Scroll down to the **Artifacts** section
3. Tap **MeshLink-IPA** — this downloads a zip file
4. Open the zip from your Downloads (Files app)
5. Inside is **MeshLink.ipa** — this is your app!

---

## Part 6: Install via Signulous

1. Open the **Signulous** app on your iPhone
2. Tap **My Apps** → **Upload IPA**
3. Browse to your Downloads and select **MeshLink.ipa**
4. Signulous will re-sign the app with your certificate
5. Tap **Install**
6. MeshLink appears on your home screen!

### If Signulous says "Unable to install":
- Make sure your Signulous subscription is active
- Try restarting your iPhone and installing again
- In rare cases you may need to delete any old MeshLink installs first

---

## Part 7: First Launch

1. Open **MeshLink** from your home screen
2. iOS will ask **"MeshLink Would Like to Use Bluetooth"** — tap **OK** (required!)
3. Enter your **node name** (your display name in chats)
4. Enter an **encryption key** (share the same key with whoever you want to chat with)
5. Tap **Join Mesh**
6. Go to the **Peers** tab → tap **Scan for Devices**
7. Connect to any nearby device running MeshLink

---

## Updating the App Later

If I give you updated code:

1. Go to your GitHub repo
2. Navigate to the file that changed
3. Tap the pencil icon (edit)
4. Replace the contents
5. Commit — the build automatically re-runs
6. Download the new IPA from Actions → install via Signulous again

---

## Troubleshooting

**"No Bluetooth" warning:**
→ Go to Settings → Bluetooth → make sure it is ON. Restart MeshLink.

**No devices found when scanning:**
→ The other device must also be running MeshLink (or the Python companion server). Both devices need to be scanning or advertising.

**Messages are garbled:**
→ Both devices must use the EXACT same encryption key. It is case-sensitive.

**Build fails with "No such module 'CryptoKit'":**
→ Make sure the workflow uses macos-14 runner (it does by default). CryptoKit requires iOS SDK 13+.

**Build fails with "scheme not found":**
→ The project.yml file wasn't uploaded correctly. Make sure it is in the root of the repo (not inside a folder).
