# App Store Distribution Script Setup Guide

This guide will help you set up the `publish_appstore.sh` script to build and upload the IngrediCheck app to App Store Connect.

## Prerequisites

1. **Xcode** (latest version recommended)
   - Verify installation: `xcodebuild -version`
   - Ensure Xcode command line tools are installed

2. **Transporter App**
   - Install from the Mac App Store: [Transporter](https://apps.apple.com/us/app/transporter/id1450874784)
   - Or ensure it's available via Xcode (included with Xcode 15+)

3. **Apple Developer Account Access**
   - You need access to the Apple Developer account for team `58MYNHGN72` (FUNGEE LLC)
   - You need **Account Holder** or **Admin** access to App Store Connect

## Step 1: Create App Store Connect API Key

1. Go to [App Store Connect](https://appstoreconnect.apple.com/)
2. Navigate to **Users and Access** → **Integrations** → **App Store Connect API**
3. Click the **"+"** button to create a new key
4. Choose **Individual Keys** (or Team Keys if your team prefers)
5. Provide a name (e.g., "CI/CD Distribution Key")
6. Select **App Manager** or **Admin** access level
7. Click **Generate**
8. **IMPORTANT**: Download the `.p8` private key file immediately (you can only download it once!)
9. Note the following values:
   - **Key ID** (e.g., `OTZKTEFV3F6Z`)
   - **Issuer ID** (found at the top of the Keys page, looks like a UUID)

## Step 2: Set Up Distribution Certificate and Provisioning Profile

### Create Apple Distribution Certificate

1. Open **Xcode** → **Settings** (⌘,) → **Accounts**
2. Select your Apple ID → click **Manage Certificates...**
3. Click the **"+"** button at the bottom left
4. Choose **Apple Distribution**
5. Xcode will create and install the certificate automatically

### Create App Store Provisioning Profile

1. Go to [Apple Developer Portal](https://developer.apple.com/account/resources/profiles/list)
2. Click **"+"** to create a new profile
3. Select **App Store** (under Distribution)
4. Select your App ID: `llc.fungee.ingredicheck`
5. Select the **Apple Distribution** certificate you just created
6. Name it (e.g., "IngrediCheck App Store")
7. Click **Generate**
8. Download the `.mobileprovision` file
9. Double-click the file to install it in Xcode

### Configure Xcode Signing

1. Open `IngrediCheck.xcworkspace` in Xcode
2. Select the **IngrediCheck** project in the navigator
3. Select the **IngrediCheck** target
4. Go to **Signing & Capabilities** tab
5. Switch to **Release** configuration (top dropdown)
6. Ensure **Automatically manage signing** is checked
   - Xcode should automatically select your Apple Distribution certificate and App Store provisioning profile
7. Verify it shows:
   - **Signing Certificate**: Apple Distribution: FUNGEE LLC (58MYNHGN72)
   - **Provisioning Profile**: IngrediCheck App Store

## Step 3: Configure Environment Variables

1. Copy the `.p8` private key file to the `publish/` directory:
   ```bash
   cp ~/Downloads/AuthKey_XXXXXXXX.p8 publish/
   ```
   Or if you downloaded it as `ApiKey_XXXXXXXX.p8`:
   ```bash
   cp ~/Downloads/ApiKey_XXXXXXXX.p8 publish/
   ```

2. Create a `.env` file in the `publish/` directory:
   ```bash
   cd publish
   touch .env
   ```

3. Edit `.env` and add your credentials:
   ```bash
   APP_STORE_CONNECT_API_KEY=YOUR_KEY_ID_HERE
   APP_STORE_CONNECT_API_ISSUER=YOUR_ISSUER_ID_HERE
   APP_STORE_CONNECT_API_PRIVATE_KEY_PATH=./ApiKey_YOUR_KEY_ID.p8
   APP_STORE_CONNECT_API_KEY_TYPE=individual
   ```

   Replace:
   - `YOUR_KEY_ID_HERE` with your actual Key ID (e.g., `OTZKTEFV3F6Z`)
   - `YOUR_ISSUER_ID_HERE` with your Issuer ID (e.g., `9b6ab061-e88d-411f-8828-677c9b84011c`)
   - `ApiKey_YOUR_KEY_ID.p8` with the actual filename of your `.p8` file
   - `individual` with `team` if you created a Team Key instead

   **Example:**
   ```bash
   APP_STORE_CONNECT_API_KEY=OTZKTEFV3F6Z
   APP_STORE_CONNECT_API_ISSUER=9b6ab061-e88d-411f-8828-677c9b84011c
   APP_STORE_CONNECT_API_PRIVATE_KEY_PATH=./ApiKey_OTZKTEFV3F6Z.p8
   APP_STORE_CONNECT_API_KEY_TYPE=individual
   ```

4. **Security Note**: The `.env` file and `.p8` files are already in `.gitignore`, so they won't be committed to the repository. Keep them secure!

## Step 4: Verify Setup

1. Make sure the script is executable:
   ```bash
   chmod +x publish/publish_appstore.sh
   ```

2. Test the script (without uploading):
   ```bash
   SKIP_UPLOAD=1 ./publish/publish_appstore.sh
   ```

   This will:
   - Archive the app
   - Create an IPA
   - Skip the upload step

   If this succeeds, your setup is correct!

## Step 5: Run the Full Distribution

Once everything is set up, run:

```bash
./publish/publish_appstore.sh
```

The script will:
1. ✅ Auto-increment the build number (just like Xcode does)
2. ✅ Archive the app with distribution signing
3. ✅ Create an IPA file
4. ✅ Upload to App Store Connect via iTMSTransporter

## Troubleshooting

### "Transporter CLI not found"
- Install the Transporter app from the Mac App Store
- Or ensure Xcode is properly installed and selected: `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`

### "Unable to detect DEVELOPMENT_TEAM"
- Ensure your Xcode project has the Development Team set in Signing & Capabilities
- Or set `APPLE_TEAM_ID=58MYNHGN72` in your `.env` file

### "Authentication credentials are missing or invalid"
- Verify your API Key ID and Issuer ID are correct in `.env`
- Ensure the `.p8` file path is correct and the file exists
- Check that the `.p8` file is named correctly: `ApiKey_<KEY_ID>.p8` or `AuthKey_<KEY_ID>.p8`

### "The bundle version must be higher than the previously uploaded version"
- The script should auto-increment the build number, but if you see this error:
  - Check App Store Connect to see what the latest build number is
  - Manually increment it in Xcode if needed

### Build doesn't appear in App Store Connect
- Wait a few minutes for Apple to process the upload
- Check App Store Connect → Your App → TestFlight
- Look for any processing errors in App Store Connect

## Additional Notes

- The script automatically increments build numbers before each upload
- Build artifacts are stored in `build/` directory (already in `.gitignore`)
- The script uses `agvtool` to manage version numbers, which requires the project to be configured for it
- If you encounter issues with `agvtool`, the script will fall back to timestamp-based build numbers

## Need Help?

If you encounter issues not covered here, check:
1. The script output for specific error messages
2. App Store Connect for build processing status
3. Xcode's signing and capabilities settings

