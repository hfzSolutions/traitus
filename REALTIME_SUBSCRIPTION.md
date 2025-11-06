# Realtime Message Subscription & Unread Tracking

This document explains the realtime message subscription feature that enables live updates and unread message tracking in the Traitus AI chat application.

## Overview

The app uses **Supabase Realtime** to subscribe to new message events, allowing the chat list to update in real-time when new AI responses arrive, even when the user is not actively viewing that chat.

## Features

1. **Live Chat Updates**: Chat list automatically updates when new messages arrive
2. **Unread Message Badges**: Visual indicators show how many unread messages each chat has
3. **Sound & Vibration Notifications**: Audio and haptic feedback when new messages arrive (only when not viewing that chat)
4. **Smart Read Tracking**: Messages are automatically marked as read when you open a chat

## Supabase Setup Required

### 1. Enable Realtime for Messages Table

In your Supabase Dashboard:

1. Go to **Database** → **Replication**
2. Find the **`messages`** table
3. Enable **Realtime** for the `messages` table
   - Alternatively, go to **Database** → **Publications** → **supabase_realtime**
   - Add `messages` table to the publication

### 2. Verify Row Level Security (RLS)

Ensure RLS policies are set up correctly (already in `supabase_schema.sql`):

```sql
-- Messages should already have these policies
CREATE POLICY "Users can view their own messages"
    ON messages FOR SELECT
    USING (auth.uid() = user_id);
```

## How It Works

### Architecture

```
┌─────────────────┐
│  Chat List UI   │
│  (ChatListPage) │
└────────┬────────┘
         │
         ▼
┌─────────────────────┐
│ ChatsListProvider   │
│ - Manages chat list │
│ - Subscribes to     │
│   realtime events   │
└────────┬────────────┘
         │
         ▼
┌─────────────────────┐
│ Supabase Realtime  │
│ Channel Subscription│
└─────────────────────┘
         │
         ▼
┌─────────────────────┐
│  messages table     │
│  (INSERT events)    │
└─────────────────────┘
```

### Implementation Details

#### 1. Subscription Setup

The subscription is initialized in `ChatsListProvider` when chats are loaded:

```dart
void _ensureRealtimeSubscribed() {
  if (_messagesChannel != null) return; // Already subscribed
  
  _messagesChannel = SupabaseService.client.channel('messages-inserts')
    ..onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (payload) {
        // Handle new message
      },
    );
  
  _messagesChannel!.subscribe();
}
```

#### 2. Event Handling

When a new message is inserted:

1. **Filter**: Only processes assistant messages for the current user
2. **Update Chat**: Updates the chat's `lastMessage` and `lastMessageTime`
3. **Unread Logic**:
   - If user is viewing the chat → mark as read (unreadCount = 0)
   - If user is NOT viewing the chat → increment unreadCount
4. **Notifications**: Play sound and vibration if user is not viewing
5. **UI Update**: Notify listeners to refresh the chat list

**Important**: The realtime subscription is the **single source of truth** for updating last messages when bot responses arrive. This prevents race conditions and ensures unread badges persist correctly. The `ChatProvider` does not call `updateLastMessage` for bot responses - it relies on the realtime subscription to handle this automatically.

#### 3. Active Chat Tracking

The app tracks which chat is currently being viewed:

```dart
void setActiveChat(String? chatId) {
  _activeChatId = chatId;
}
```

- Set when opening a chat: `setActiveChat(chatId)`
- Cleared when returning to chat list: `setActiveChat(null)`
- Cleared when chat page is disposed

#### 4. Unread Count Calculation

Unread count is calculated in two ways:

**Initial Load**:
```dart
Future<void> _refreshUnreadCounts() async {
  // Count assistant messages created after last_read_at
  final count = await _dbService.getUnreadCount(
    chat.id,
    since: chat.lastReadAt ?? chat.createdAt,
  );
}
```

**Realtime Updates**:
```dart
// When new message arrives
if (_activeChatId == chatId) {
  // Mark as read
  updated = updated.copyWith(unreadCount: 0, lastReadAt: DateTime.now());
} else {
  // Increment unread count
  final newUnreadCount = (currentChat.unreadCount + 1).clamp(1, 999);
  updated = updated.copyWith(unreadCount: newUnreadCount);
}
```

#### 5. Last Message Display

The chat list displays the **actual last message** in the conversation, whether it's from the user or the bot:

- **User messages**: Updated immediately when sent (via `updateLastMessage` in `chat_page.dart`)
- **Bot responses**: Updated automatically by the realtime subscription when the message is saved to the database

**Key Implementation Details**:
- The `updateLastMessage` method explicitly preserves `unreadCount` and `lastReadAt` to prevent accidental resets
- Bot responses are handled exclusively by the realtime subscription to avoid race conditions
- This ensures the chat list always shows the most recent message, and unread badges persist correctly

## Database Schema

### Chats Table

Added `last_read_at` column to track when user last viewed a chat:

```sql
ALTER TABLE chats
ADD COLUMN IF NOT EXISTS last_read_at TIMESTAMPTZ;
```

See `supabase_migration_add_last_read.sql` for the complete migration.

### Messages Table

No changes needed - uses existing `created_at` and `role` columns.

## User Experience Flow

### Scenario 1: User Sends Message and Waits

1. User sends message in Chat A
2. User stays in Chat A
3. AI response arrives → No badge, no sound (user is viewing)
4. Message is marked as read automatically

### Scenario 2: User Sends Message and Navigates Away

1. User sends message in Chat A
2. User navigates back to chat list
3. `_activeChatId` is cleared (set to `null`)
4. AI response arrives → Badge appears, sound/vibration plays
5. User sees updated last message and unread badge
6. User opens Chat A → Badge clears, message marked as read

### Scenario 3: Multiple Chats

1. User has multiple chats
2. New message arrives in Chat B while viewing Chat A
3. Chat B shows badge, plays sound
4. Chat A continues normally (no interruption)

## Notification Features

### Sound Notification

- Uses Flutter's `SystemSound.play(SystemSoundType.alert)`
- Respects system volume settings
- On iOS: Respects silent switch (may be quiet/muted)
- Fallback to `SystemSoundType.click` if alert fails

### Vibration

- Uses `HapticFeedback.mediumImpact()`
- More reliable than sound
- Works even in silent mode
- Always attempts to vibrate (sound is optional)

## Code Locations

### Key Files

- `lib/providers/chats_list_provider.dart` - Main subscription logic
- `lib/services/database_service.dart` - Unread count queries
- `lib/models/ai_chat.dart` - Model with `lastReadAt` and `unreadCount`
- `lib/ui/chat_list_page.dart` - UI displaying unread badges
- `lib/ui/chat_page.dart` - Sets active chat when opened

### Key Methods

- `_ensureRealtimeSubscribed()` - Sets up the subscription
- `setActiveChat(String?)` - Tracks which chat is active
- `markChatAsRead(String)` - Marks chat as read and updates DB
- `_playNotificationSound()` - Plays sound and vibration
- `_refreshUnreadCounts()` - Calculates unread counts on load
- `updateLastMessage(String, String)` - Updates last message while preserving unread count

## Testing

### Test the Subscription

1. **Enable Realtime** in Supabase Dashboard
2. **Send a message** in a chat
3. **Navigate back** to chat list
4. **Wait for AI response**
5. **Verify**:
   - Chat's last message updates in real-time
   - Unread badge appears
   - Sound/vibration plays
   - Console shows debug logs

### Debug Logs

The implementation includes comprehensive debug logging:

```
flutter: Realtime message received for chat <id>, activeChatId: null
flutter: User NOT viewing chat <id>: unreadCount 0 -> 1
flutter: Playing notification sound and vibration...
flutter: Vibration triggered successfully
flutter: Notification sound played successfully (alert)
```

### Common Issues

**No realtime updates?**
- Check Supabase Dashboard → Replication → Messages table is enabled
- Verify RLS policies allow reading messages
- Check console for subscription errors

**No sound/vibration?**
- Check console logs to see if function is called
- iOS: Check silent switch position
- Android: Check notification permissions
- Verify device volume is up

**Badge not showing or disappearing?**
- Check console for unread count logs
- Verify `_activeChatId` is properly cleared when navigating back
- Check if `notifyListeners()` is being called
- Ensure `updateLastMessage` preserves `unreadCount` (should not reset it)
- Verify realtime subscription is handling bot responses (not manual `updateLastMessage` calls)

## Performance Considerations

- Subscription is created once per provider lifetime
- Only processes assistant messages (filters user messages)
- Only processes messages for the current user (RLS + client-side filter)
- Unread count updates are optimistic (UI updates immediately, DB syncs async)
- Sound/vibration are non-blocking

## Future Enhancements

Possible improvements:

1. **Per-message read tracking**: Track which individual messages have been read
2. **Read receipts**: Show when user has read a message
3. **Custom notification sounds**: Allow users to choose notification sounds
4. **Notification settings**: User preferences for sound/vibration
5. **Push notifications**: For when app is in background
6. **Batch unread updates**: Optimize when multiple messages arrive quickly

## Related Documentation

- `supabase_migration_add_last_read.sql` - Database migration
- `supabase_schema.sql` - Complete database schema
- `DATABASE_DESIGN.md` - Overall database design

