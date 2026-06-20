
# COMPREHENSIVE NOTIFICATION SYSTEM AUDIT REPORT

## Date: 2026-06-19

---

## 1. EXECUTIVE SUMMARY

We have completed a full audit of the LitOps notification system. The system architecture is:
- Flutter mobile app
- Firebase Cloud Messaging (FCM)
- Supabase Backend (PostgreSQL + Edge Functions)

We have enhanced logging across all layers to enable full end-to-end debugging.

---

## 2. ENHANCEMENTS & FIXES IMPLEMENTED

### ✅ 2.1 Edge Function Logging
**File**: `litops/supabase/functions/send-push/index.ts`

**Changes**:
- Added `maskToken()` helper to safely log tokens without exposing full values
- Added extensive logging for:
  - Function start
  - Incoming request body
  - Notification payload (userId, title, message, payloadId)
  - Supabase client initialization
  - Token fetching process (tokens found, masked tokens)
  - Firebase credential loading
  - Access token generation
  - FCM request body
  - FCM response status & body
  - Success/failure summary
  - Invalid token cleanup
  - Full error stack traces

### ✅ 2.2 Flutter Notification Service Logging
**File**: `litops/lib/core/services/notification_service.dart`

**Changes**:
- Added comprehensive logging with `[NotificationService]` prefix
- Added detailed logs for:
  - Initialization
  - Permission request results
  - Token generation & refresh
  - Token upsert to Supabase (including responses)
  - Auth state changes (login/logout)
  - Supabase realtime listener status
  - Foreground/background/terminated FCM messages
  - Local notification display
  - Full error stack traces

### ✅ 2.3 Database Audit Script
**File**: `litops/supabase/audit_notification_system.sql`

**Queries Included**:
1. Recent user_fcm_tokens
2. Number of users with tokens
3. Duplicate tokens check
4. Recent notifications
5. Recent event assignments with user & event details
6. Notifications where user has no tokens
7. Tokens per user summary
8. Trigger definitions
9. RLS policies
10. Stale tokens (not updated in 30 days)

---

## 3. TROUBLESHOOTING CHECKLIST

### Step 1: Verify User Has a Valid Token
- **Action**: Have the user log out and log back in
- **Check Flutter Logs**: Look for:
  ```
  [NotificationService] === REGISTERING FCM TOKEN ===
  [NotificationService] User ID: <user-id>
  [NotificationService] Generated FCM token: <token>
  [NotificationService] Token saved successfully! Response: ...
  ```
- **Check Database**: Run audit script to verify token exists in `user_fcm_tokens`

### Step 2: Test Event Assignment
- **Action**: As admin, assign the user to an event
- **Check Database**: Verify:
  1. Row exists in `event_assignments`
  2. Row exists in `notifications` with correct user_id
- **Check Edge Function Logs**:
  - Look in Supabase Dashboard → Edge Functions → send-push → Logs
  - Verify full flow: request received → tokens found → FCM sent → success

### Step 3: Verify Firebase Setup
- Ensure `FIREBASE_SERVICE_ACCOUNT` environment variable is set in Supabase Edge Function config
- Verify Firebase project ID matches

### Step 4: Verify PostgreSQL Extensions & Triggers
- **Check pg_net extension**:
  ```sql
  SELECT extname FROM pg_extension WHERE extname = 'pg_net';
  ```
- **Check triggers**:
  ```sql
  SELECT tgname FROM pg_trigger WHERE tgname IN ('on_crew_assigned', 'on_notification_created');
  ```

---

## 4. SYSTEM ARCHITECTURE RECAP

```
Admin assigns user
    ↓
Insert into event_assignments
    ↓
TRIGGER on_crew_assigned → Insert into notifications
    ↓
TRIGGER on_notification_created → Call send-push Edge Function via pg_net
    ↓
Edge Function:
    1. Fetch user's tokens from user_fcm_tokens
    2. Generate Firebase access token
    3. Send FCM notification to each token
    4. Clean up invalid tokens
```

---

## 5. NEXT STEPS

1. **Deploy Updated Edge Function**:
   ```bash
   cd litops
   supabase functions deploy send-push
   ```

2. **Run Flutter App & Test Login**:
   - Check logs to verify token is generated and saved
   - Use the audit SQL script to confirm token is in database

3. **Assign User & Verify Full Flow**:
   - Check database for assignment and notification
   - Check Edge Function logs
   - Verify user receives push notification

4. **Monitor Logs**:
   - Check Flutter logs for token registration
   - Check Edge Function logs for notification delivery
   - Use the audit SQL script periodically

---

## 6. KEY FILES

| File | Purpose |
|------|---------|
| `litops/lib/core/services/notification_service.dart` | Flutter notification handling & token management |
| `litops/supabase/functions/send-push/index.ts` | Edge Function that sends FCM notifications |
| `litops/supabase/create_fcm_tokens_table.sql` | FCM tokens table & trigger to call Edge Function |
| `litops/supabase/create_crew_assignment_notification_trigger.sql` | Trigger for event assignments → notifications |
| `litops/supabase/audit_notification_system.sql` | Database audit queries |

