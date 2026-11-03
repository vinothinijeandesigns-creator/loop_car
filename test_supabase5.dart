import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://usysfcfncfiwdqpqzije.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVzeXNmY2ZuY2Zpd2RxcHF6aWplIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk0MDc2OTMsImV4cCI6MjA4NDk4MzY5M30.XafXkazhRb9wDqJZSNb27z9G3WRRboHmZatDIMFrRDs',
  );

  final userId = '543959a0-2a23-46ab-9d4c-daf5ef634d09';
  
  try {
    print("Testing ratings insert...");
    final res = await client.from('ratings').insert({
      // We will just try an insert without valid FKs to see if RLS blocks FIRST.
      // If RLS blocks, we get 42501 Unauthorized. 
      // If FKs fail, we get a 23503 foreign_key_violation.
      'rater_id': userId,
      'ratee_id': userId,
      'rating': 5,
    }).select();
    print("Inserted successfully! Returning: $res");
  } catch (e) {
    print("Insert Error: $e");
  }
}
