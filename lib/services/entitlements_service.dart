import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:traitus/services/supabase_service.dart';

enum UserPlan { free, pro }

class EntitlementsService {
  EntitlementsService({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<UserPlan> getCurrentUserPlan() async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) return UserPlan.free;

      // Expect a table `user_entitlements` with columns: user_id, plan ('free'|'pro'), status
      final resp = await _client
          .from('user_entitlements')
          .select('plan, status')
          .eq('user_id', userId)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (resp == null) return UserPlan.free;
      final status = (resp['status'] as String?)?.toLowerCase();
      if (status != 'active') return UserPlan.free;

      final plan = (resp['plan'] as String?)?.toLowerCase();
      return plan == 'pro' ? UserPlan.pro : UserPlan.free;
    } catch (_) {
      // Safe fallback to Free if Supabase isn't ready or table missing
      return UserPlan.free;
    }
  }
}
