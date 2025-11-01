# Chat Ordering and Pinning Feature

## Overview
This feature allows users to organize their chats by:
1. **Pinning** important chats to the top
2. **Drag-and-drop reordering** within pinned and unpinned sections

## Implementation Details

### Database Changes
**Migration File:** `supabase_migration_add_pinning_ordering.sql`

Added two new columns to the `chats` table:
- `is_pinned` (BOOLEAN, default: FALSE) - Indicates if a chat is pinned
- `sort_order` (INTEGER, default: 0) - Custom sort order within each section

**To apply this migration:**
1. Open your Supabase SQL Editor
2. Run the SQL from `supabase_migration_add_pinning_ordering.sql`

### Model Changes
**File:** `lib/models/ai_chat.dart`

Added fields:
- `bool isPinned` - Pin status
- `int sortOrder` - Sort order for drag-and-drop positioning

### Database Service
**File:** `lib/services/database_service.dart`

Updated `fetchChats()` to order by:
1. `is_pinned` (descending - pinned first)
2. `sort_order` (ascending - custom order)
3. `created_at` (descending - newest first)

### Provider Changes
**File:** `lib/providers/chats_list_provider.dart`

Added methods:
- `togglePin(String chatId)` - Toggle pin status of a chat
- `reorderChats(int oldIndex, int newIndex)` - Handle drag-and-drop reordering
- `_sortChats()` - Sort chats locally by pinned status and sort order

### UI Changes
**File:** `lib/ui/chat_list_page.dart`

1. **Replaced ListView with ReorderableListView**
   - Enables drag-and-drop functionality
   - Items can be reordered by dragging

2. **Added Section Headers**
   - "Pinned" section for pinned chats
   - "All Chats" section for unpinned chats
   - Only shown when both sections have items

3. **Added Drag Handle**
   - Shows a drag icon on the left side of each chat
   - Users can grab this to reorder chats

4. **Added Pin Button**
   - Icon button on the right side of each chat
   - Shows filled pin icon when pinned
   - Shows outlined pin icon when unpinned
   - Tapping toggles the pin status

5. **Added Pin Indicator**
   - Small pin icon next to the chat name for pinned chats
   - Colored with the primary theme color

6. **Added 3-Dot Menu in Chat Page** (NEW)
   - Located in the app bar when viewing a chat
   - Provides quick access to:
     - "Edit Chat Settings" - Opens the edit modal
     - "Clear All Messages" - Clears the conversation history

## User Experience

### Editing Chat Settings
You can edit a chat's name and system prompt in two ways:

**Option 1: From the Chat List Page**
1. Long press on any chat in the list
2. The Edit Chat Settings modal opens
3. Modify the chat name and/or system prompt
4. Tap "Save Changes"

**Option 2: From within the Chat (NEW)**
1. Open any chat
2. Tap the 3-dot menu (⋮) button in the top right
3. Select "Edit Chat Settings"
4. Modify the chat name and/or system prompt
5. Tap "Save Changes"

The app bar will update immediately to show the new chat name.

### Pinning a Chat
1. Tap the pin icon on the right side of any chat
2. The chat moves to the "Pinned" section at the top
3. The pin icon becomes filled and colored

### Unpinning a Chat
1. Tap the filled pin icon on a pinned chat
2. The chat moves back to the "All Chats" section
3. The pin icon returns to outlined style

### Reordering Chats
1. **Press and hold the drag handle (≡ icon)** on the left side of the chat
2. Drag the chat up or down to the desired position
3. Release to drop it in place
4. Chats can only be reordered within their section (pinned or unpinned)

**Important:** The drag handle is separate from the rest of the chat item:
- **Drag handle (≡)**: Hold this to drag and reorder
- **Rest of chat**: Tap to open, long press to edit
- This separation prevents gesture conflicts

### Restrictions
- You cannot drag a pinned chat into the unpinned section (and vice versa)
- You must unpin a chat first to move it to the unpinned section
- Each section maintains its own ordering

## Visual Indicators

1. **Pinned Chats:**
   - Appear at the top under "Pinned" header
   - Show a small pin icon next to the name
   - Pin button is filled and highlighted

2. **Unpinned Chats:**
   - Appear below pinned chats under "All Chats" header
   - No pin icon next to the name
   - Pin button is outlined and subtle

3. **Drag Handle:**
   - Always visible on the left side
   - Indicates that the chat can be reordered

## Technical Notes

### Order Persistence
- Sort order is persisted to the database immediately when changed
- When you reorder a chat, all chats in that section get their `sort_order` updated
- The app maintains the order across sessions

### Performance
- Reordering updates only the affected section's chats
- Pin/unpin triggers a local re-sort for instant feedback
- All changes are synced to Supabase in the background

### Error Handling
- If a database operation fails, an error is logged
- The UI will revert to the last known good state
- Users can retry the operation

## Future Enhancements

Possible improvements:
- Add a "Pin/Unpin" option to the long-press menu
- Add visual feedback during drag operations (elevation, shadow)
- Add haptic feedback on pin/unpin
- Add undo functionality for reordering
- Add bulk operations (pin multiple chats at once)

