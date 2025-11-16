// Supabase Edge Function: Send Re-engagement Notifications
// This function identifies inactive users and sends personalized push notifications
// via OneSignal to re-engage them with their most recent/active AI chat
//
// NOTE: This file is for REFERENCE ONLY.
// The actual function is deployed and running in Supabase Dashboard → Edge Functions.
// All code below is commented out to avoid local IDE errors (Deno not installed locally).

/*
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const ONESIGNAL_APP_ID = Deno.env.get('ONESIGNAL_APP_ID')
const ONESIGNAL_REST_API_KEY = Deno.env.get('ONESIGNAL_REST_API_KEY')
const INACTIVITY_DAYS = 7 // Days of inactivity before sending notification
const MIN_NOTIFICATION_INTERVAL_DAYS = 7 // Minimum days between notifications

// Notification message templates
const NOTIFICATION_TEMPLATES = [
  (aiName: string) => `Continue your conversation with ${aiName}`,
  (aiName: string) => `${aiName} is waiting for you!`,
  (aiName: string) => `It's been a while! ${aiName} misses you`,
  (aiName: string) => `Pick up where you left off with ${aiName}`,
]

serve(async (req) => {
  try {
    // Validate environment variables
    if (!ONESIGNAL_APP_ID || !ONESIGNAL_REST_API_KEY) {
      throw new Error('Missing OneSignal configuration. Set ONESIGNAL_APP_ID and ONESIGNAL_REST_API_KEY in Supabase secrets.')
    }

    // Create Supabase client with service role key for admin access
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Calculate the cutoff date for inactive users
    const cutoffDate = new Date()
    cutoffDate.setDate(cutoffDate.getDate() - INACTIVITY_DAYS)

    // Find inactive users
    // Users who:
    // 1. Have last_app_activity older than INACTIVITY_DAYS days
    // 2. Have re_engagement_enabled = true
    // 3. Haven't received a notification in the last MIN_NOTIFICATION_INTERVAL_DAYS days (or never)
    const minNotificationIntervalDate = new Date()
    minNotificationIntervalDate.setDate(minNotificationIntervalDate.getDate() - MIN_NOTIFICATION_INTERVAL_DAYS)

    const { data: inactiveUsers, error: usersError } = await supabase
      .from('user_profiles')
      .select('id, last_app_activity, last_re_engagement_sent')
      .eq('re_engagement_enabled', true)
      .lt('last_app_activity', cutoffDate.toISOString())
      .or(`last_re_engagement_sent.is.null,last_re_engagement_sent.lt.${minNotificationIntervalDate.toISOString()}`)

    if (usersError) {
      throw new Error(`Error fetching inactive users: ${usersError.message}`)
    }

    if (!inactiveUsers || inactiveUsers.length === 0) {
      return new Response(
        JSON.stringify({ 
          success: true, 
          message: 'No inactive users found',
          usersProcessed: 0 
        }),
        { headers: { 'Content-Type': 'application/json' } }
      )
    }

    console.log(`Found ${inactiveUsers.length} inactive users`)

    let successCount = 0
    let errorCount = 0
    const results: Array<{ userId: string; success: boolean; error?: string }> = []

    // Process each inactive user
    for (const user of inactiveUsers) {
      try {
        // Find the user's most relevant chat
        // Priority: 1) Most recent last_message_time, 2) Most messages, 3) Most recent created_at
        const { data: chats, error: chatsError } = await supabase
          .from('chats')
          .select('id, name, last_message_time, created_at')
          .eq('user_id', user.id)
          .order('last_message_time', { ascending: false, nullsFirst: false })
          .limit(1)

        if (chatsError) {
          throw new Error(`Error fetching chats: ${chatsError.message}`)
        }

        // If no chat with last_message_time, try to get the most recent chat by created_at
        let selectedChat = chats?.[0]
        if (!selectedChat || !selectedChat.last_message_time) {
          const { data: recentChats, error: recentChatsError } = await supabase
            .from('chats')
            .select('id, name, created_at')
            .eq('user_id', user.id)
            .order('created_at', { ascending: false })
            .limit(1)

          if (!recentChatsError && recentChats && recentChats.length > 0) {
            selectedChat = recentChats[0]
          }
        }

        // Skip if user has no chats
        if (!selectedChat) {
          console.log(`User ${user.id} has no chats, skipping`)
          results.push({ userId: user.id, success: false, error: 'No chats found' })
          errorCount++
          continue
        }

        // Select a random notification template
        const templateIndex = Math.floor(Math.random() * NOTIFICATION_TEMPLATES.length)
        const notificationMessage = NOTIFICATION_TEMPLATES[templateIndex](selectedChat.name)

        // Send notification via OneSignal
        const oneSignalResponse = await fetch('https://onesignal.com/api/v1/notifications', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Basic ${ONESIGNAL_REST_API_KEY}`,
          },
          body: JSON.stringify({
            app_id: ONESIGNAL_APP_ID,
            include_external_user_ids: [user.id], // Use Supabase user ID as external user ID
            contents: { en: notificationMessage },
            headings: { en: 'We miss you!' },
            data: {
              type: 're_engagement',
              chat_id: selectedChat.id,
              chat_name: selectedChat.name,
            },
          }),
        })

        if (!oneSignalResponse.ok) {
          const errorText = await oneSignalResponse.text()
          throw new Error(`OneSignal API error: ${oneSignalResponse.status} - ${errorText}`)
        }

        const oneSignalResult = await oneSignalResponse.json()
        console.log(`Sent notification to user ${user.id} for chat ${selectedChat.id}`)

        // Update last_re_engagement_sent timestamp
        const { error: updateError } = await supabase
          .from('user_profiles')
          .update({ last_re_engagement_sent: new Date().toISOString() })
          .eq('id', user.id)

        if (updateError) {
          console.error(`Error updating last_re_engagement_sent for user ${user.id}: ${updateError.message}`)
          // Don't fail the whole operation, just log the error
        }

        successCount++
        results.push({ 
          userId: user.id, 
          success: true,
        })
      } catch (error) {
        console.error(`Error processing user ${user.id}:`, error)
        errorCount++
        results.push({ 
          userId: user.id, 
          success: false, 
          error: error instanceof Error ? error.message : String(error)
        })
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: `Processed ${inactiveUsers.length} inactive users`,
        stats: {
          total: inactiveUsers.length,
          successful: successCount,
          errors: errorCount,
        },
        results,
      }),
      { headers: { 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Edge function error:', error)
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : String(error),
      }),
      { 
        status: 500,
        headers: { 'Content-Type': 'application/json' } 
      }
    )
  }
})
*/
