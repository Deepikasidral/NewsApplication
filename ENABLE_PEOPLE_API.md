# ⚠️ REQUIRED: Enable Google People API

## The Google Sign-In is failing because People API is disabled!

### Quick Fix (2 minutes):

1. **Click this link**: https://console.developers.google.com/apis/api/people.googleapis.com/overview?project=970893975704

2. **Click the blue "ENABLE" button**

3. **Wait 1-2 minutes** for activation

4. **Restart your Flutter app**:
   ```bash
   flutter run -d chrome
   ```

### Why is this needed?
The `google_sign_in` package on web uses the People API to fetch user profile information (name, email, photo). Without it enabled, authentication fails.

### Alternative (if you can't enable it):
Use Firebase Auth UI or implement a custom OAuth flow without the google_sign_in package.
