// Supabase Edge Function: Delete User Account
// This function allows users to delete their own account
// It uses the service role key to perform the deletion with proper CASCADE handling
//
// NOTE: This file is for REFERENCE ONLY.
// The actual function is deployed and running in Supabase Dashboard → Edge Functions.
// All code below is commented out to avoid local IDE errors (Deno not installed locally).

/*
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  try {
    // Get the authorization header to verify the user
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          error: 'Missing authorization header' 
        }),
        { 
          status: 401,
          headers: { 'Content-Type': 'application/json' } 
        }
      )
    }

    // Extract the JWT token from the Authorization header
    const token = authHeader.replace('Bearer ', '')
    
    // Create Supabase client with anon key to verify the user
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!
    const supabase = createClient(supabaseUrl, supabaseAnonKey)
    
    // Verify the user's token and get their user ID
    const { data: { user }, error: userError } = await supabase.auth.getUser(token)
    
    if (userError || !user) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          error: 'Invalid or expired token' 
        }),
        { 
          status: 401,
          headers: { 'Content-Type': 'application/json' } 
        }
      )
    }

    const userId = user.id
    console.log(`User ${userId} requested account deletion`)

    // Create Supabase client with service role key for admin operations
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey)

    // Delete the user using the admin client
    // This will trigger CASCADE deletions for all related data:
    // - user_profiles
    // - user_entitlements
    // - notes (and note_sections via CASCADE)
    // - chats (and messages via CASCADE)
    // - Storage files (via cleanup_user_storage trigger)
    const { data: deleteData, error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(userId)

    if (deleteError) {
      console.error(`Error deleting user ${userId}:`, deleteError)
      return new Response(
        JSON.stringify({ 
          success: false, 
          error: deleteError.message || 'Failed to delete user account' 
        }),
        { 
          status: 500,
          headers: { 'Content-Type': 'application/json' } 
        }
      )
    }

    console.log(`Successfully deleted user account ${userId}`)

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Account deleted successfully',
        userId: userId,
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

