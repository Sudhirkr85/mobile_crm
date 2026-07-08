# 📱 Institute CRM Mobile Application

A cross-platform Flutter mobile application designed for students, coordinators, and employees. This app interacts directly with the Institute CRM backend hosted at `https://sssam-r3pz.onrender.com/api`.

---

## 🛠️ Features Implemented

1. **Role-Based Login & Auto-Redirect**:
   - Persists JWT session and roles inside SharedPreferences.
   - Redirects to target dashboards: Admins/Counselors land on CRM Console, Employees land directly on the Geofenced Attendance Console.

2. **Geofenced Attendance Console**:
   - Location permission fetch and coordinate lookup (using `geolocator`).
   - Compares current device GPS location to target office coordinates from `/attendance/office-settings`.
   - Restricts check-in/out to specified radius.
   - Lists logs history: Date, In/Out times, Total Hours.

3. **Dashboard Console & Quick Metrics**:
   - Live metrics summary card (Gross admissions count, leads handled, revenue collection counters, and conversion rates).
   - Removed Payments module card and added specific quick access shortcuts.

4. **Staff Logs (All Staff Attendance History - Admin Only)**:
   - Fetches global logs using `/attendance/admin-history`.
   - Allows search by employee name.
   - Dynamic role-based filter option (Admins, Counselors, Employees).
   - Displays details: Date, Punch IN/OUT times, and calculated Total Hours.

5. **Enquiry & Lead Management (with Pagination)**:
   - **Infinite Scrolling Pagination**: Requests `/enquiries` page-by-page (10 items limit) with dynamic scroll controllers.
   - Leads search (by name, email, contact number) and status-based drop-down filters.
   - **Interactive Status Updater Dialog**: Update status, type detailed notes, choose/reschedule follow-up dates via calendars, and post updates to server.
   - Convert to Admission flow wrapper.

6. **Admission & Student Profiles (with Pagination)**:
   - **Infinite Scrolling Pagination**: Requests `/admissions` page-by-page (10 items limit).
   - Shows total package fees, net collections paid, and pending balances.
   - **Installment Schedules list**: Lists pending, paid, and overdue installments.
   - **Payments Ledger list**: History of payment logs.
   - **Financial Actions (Admin Only)**: Options to void payments or process partial refunds.
   - **Drop Student**: Marks student status as DROPPED with custom reasons.

7. **Reports & Analytics (Admin Only)**:
   - Fetches `/reports/summary` data and maps nested fields cleanly (mapping admissions/fees properties).
   - Shows Total Net Earnings, collected registration fees, installment collections, conversion rates, and total refunds.

8. **Add User Screen (Admin Only)**:
   - Form parameters to register new Counselor, Employee, or Admin staff members.

---

## 🚀 Getting Started

### 📋 Prerequisites
- Flutter SDK installed.
- Android SDK / Xcode for target device configurations.

### 📥 Setup Instructions
1. Navigate to the mobile project folder:
   ```bash
   cd mobile_crm
   ```
2. Fetch package dependencies:
   ```bash
   flutter pub get
   ```
3. Run the application on an emulator or connected device:
   ```bash
   flutter run
   ```

---

## 🛰️ Geofence Setup & Location Settings

The following permission settings are added to `android/app/src/main/AndroidManifest.xml` to support GPS lookups:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```
