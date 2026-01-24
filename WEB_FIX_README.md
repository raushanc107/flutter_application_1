# Web Database Fix

You experienced issues running the app on Web because **Drift (SQLite)** requires two special files to work in the browser:
1. `sqlite3.wasm` (The database engine)
2. `drift_worker.js` (A background worker to handle database operations)

These files were missing, causing the crash on Web.

## ✅ What I Fixed
1. **Downloaded** `sqlite3.wasm` to your `web/` folder.
2. **Created & Compiled** `drift_worker.js` in your `web/` folder.

## 📱 "LocalStorage" vs SQLite
You asked about using **LocalStorage**. 
- **LocalStorage** is a simple "Key-Value" store (like a Map). It cannot handle complex data like "Customers with Transactions" easily.
- **IndexedDB (via Drift)** is what we are using now. It is the proper "Database for Web" that allows specific queries, relationships, and persistence, just like SQLite on mobile.

## 🚀 How to Run
Your Web app should now work with persistent storage!

```bash
flutter run -d chrome --web-port 5555
```

If you still see issues, try running `flutter clean` first.
