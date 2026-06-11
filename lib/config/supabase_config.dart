/// Connection details for the Cura Supabase backend.
///
/// These are PUBLIC client values — the project URL and the anon (publishable)
/// key are designed to ship in client apps. They are protected by Row-Level
/// Security on the database. NEVER put the `service_role` or any secret key
/// here; those must stay server-side only.
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = 'https://urryrjnjwpkvqmgkzfdc.supabase.co';

  /// Public publishable key (safe for client apps; protected by RLS).
  static const String publishableKey =
      'sb_publishable_mKpJWmhRXjClxarqdUfxWw_uIBzABHq';
}
