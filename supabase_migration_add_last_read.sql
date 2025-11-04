-- Add last_read_at to chats to support unread indicators
ALTER TABLE chats
ADD COLUMN IF NOT EXISTS last_read_at TIMESTAMPTZ;

-- Optional: backfill existing rows to current timestamp so old messages aren't counted as unread
UPDATE chats SET last_read_at = COALESCE(last_read_at, now()) WHERE last_read_at IS NULL;

-- Helpful index when computing unread counts by comparing timestamps
CREATE INDEX IF NOT EXISTS idx_chats_last_read_at ON chats(last_read_at);

