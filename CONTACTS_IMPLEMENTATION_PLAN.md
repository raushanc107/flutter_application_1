# Plan: Import Customer from Contacts

## 1. Feasibility Report

### ✅ Mobile (iOS & Android)
- **Status**: Fully Supported.
- **Method**: Uses native OS contact pickers via `flutter_contacts`.
- **Requirements**: modifying `AndroidManifest.xml` and `Info.plist`.

### ⚠️ Web
- **Status**: **Partially Supported**.
- **Mobile Web** (Chrome on Android, Safari on iOS): ✅ Works (uses `navigator.contacts` API).
- **Desktop Web** (Chrome on Mac/Windows): ❌ **Not Supported** by most browsers.
  - Desktop browsers typically do not allow websites to access the OS address book for privacy reasons.
  - **Fallback**: The button will be visible but may show a "Not supported on this device" message or simply return no result on desktop browsers.

## 2. Implementation Plan

### Step 1: Add Dependency
Add `flutter_contacts` to `pubspec.yaml`.

```yaml
dependencies:
  flutter_contacts: ^1.1.9+1
```

### Step 2: Configure Permissions

**Android (`android/app/src/main/AndroidManifest.xml`)**:
```xml
<uses-permission android:name="android.permission.READ_CONTACTS"/>
<uses-permission android:name="android.permission.WRITE_CONTACTS"/>
```

**iOS (`ios/Runner/Info.plist`)**:
```xml
<key>NSContactsUsageDescription</key>
<string>We need access to your contacts to let you import customers easily.</string>
```

**Web**:
No configuration needed, but we must check `FlutterContacts.config.returnUnifiedContacts` or handle API availability.

### Step 3: Modify UI (`AddCustomerDialog`)
- Add a button "Import from Contacts" (e.g., an icon button next to the Name field or a text button at the top).
- **Logic**:
  1. User clicks "Import".
  2. App requests permission (if mobile).
  3. App opens Native Contact Picker.
  4. User selects contact.
  5. App fills "Name" and "Phone" fields automatically.

```dart
Future<void> _pickContact() async {
  if (kIsWeb) {
    // Web specific handling usually usually managed by package, 
    // but on Desktop it might fail gracefully.
  }
  
  if (await FlutterContacts.requestPermission()) {
    final contact = await FlutterContacts.openExternalPick();
    if (contact != null) {
      setState(() {
        _nameController.text = contact.displayName;
        if (contact.phones.isNotEmpty) {
          _phoneController.text = contact.phones.first.number;
        }
      });
    }
  }
}
```

## 3. Recommendation
Proceed with implementation. It adds significant value for Mobile users (90% of use case). For Desktop Web users, we can either hide the button or show a simple toast "Feature available on mobile devices only".
