import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:traitus/services/supabase_service.dart';

class AiModelInfo {
  AiModelInfo({
    required this.id,            // uuid
    required this.slug,          // OpenRouter slug
    required this.displayName,
    required this.tier,          // 'basic' | 'premium'
    required this.enabled,
    this.sortOrder = 0,
    this.supportsImageInput = false, // Whether model supports multimodal/image inputs
  });

  final String id; // uuid
  final String slug; // OpenRouter slug
  final String displayName;
  final String tier;
  final bool enabled;
  final int sortOrder;
  final bool supportsImageInput; // Multimodal input support flag

  bool get isPremium => tier.toLowerCase() == 'premium';
}

class ModelCatalogService {
  ModelCatalogService({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  /// Returns enabled models only. Expects a `models` table with
  /// columns: id (uuid), slug, display_name, tier, enabled, sort_order, supports_image_input
  Future<List<AiModelInfo>> listEnabledModels() async {
    try {
      final rows = await _client
          .from('models')
          .select('id, slug, display_name, tier, enabled, sort_order, supports_image_input')
          .eq('enabled', true)
          .order('sort_order', ascending: true);

      return rows.map<AiModelInfo>((m) {
        return AiModelInfo(
          id: (m['id'] as String).trim(),
          slug: (m['slug'] as String).trim(),
          displayName: (m['display_name'] as String?)?.trim() ?? (m['slug'] as String),
          tier: (m['tier'] as String?)?.toLowerCase() ?? 'basic',
          enabled: m['enabled'] as bool? ?? true,
          sortOrder: m['sort_order'] as int? ?? 0,
          supportsImageInput: m['supports_image_input'] as bool? ?? false,
        );
      }).toList();
    } catch (_) {
      // Safe fallback: single basic model from env via OPENROUTER_MODEL name
      // Using a generic display; UI can still function
      return [
        AiModelInfo(
          id: '00000000-0000-0000-0000-000000000000',
          slug: 'openrouter:env-default',
          displayName: 'Basic Model',
          tier: 'basic',
          enabled: true,
          sortOrder: 0,
          supportsImageInput: false, // Default to false for fallback
        ),
      ];
    }
  }
  
  /// Get model info by slug
  Future<AiModelInfo?> getModelBySlug(String slug) async {
    try {
      final rows = await _client
          .from('models')
          .select('id, slug, display_name, tier, enabled, sort_order, supports_image_input')
          .eq('slug', slug)
          .eq('enabled', true)
          .limit(1);
      
      if (rows.isEmpty) return null;
      
      final m = rows.first;
      return AiModelInfo(
        id: (m['id'] as String).trim(),
        slug: (m['slug'] as String).trim(),
        displayName: (m['display_name'] as String?)?.trim() ?? (m['slug'] as String),
        tier: (m['tier'] as String?)?.toLowerCase() ?? 'basic',
        enabled: m['enabled'] as bool? ?? true,
        sortOrder: m['sort_order'] as int? ?? 0,
        supportsImageInput: m['supports_image_input'] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }
}
