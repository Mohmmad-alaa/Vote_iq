import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  print('Initializing Supabase...');
  final supabase = SupabaseClient(
    'https://exvlodxhfeavyvjgucky.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV4dmxvZHhoZmVhdnl2amd1Y2t5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ3MzA1NzAsImV4cCI6MjA5MDMwNjU3MH0.jG3Z2DD-dH2hy2Uy4E4Aas5gjtMeGz_n4MbEP6W0RYw',
  );

  print('Attempting to login...');
  try {
    final response = await supabase.auth.signInWithPassword(
      email: 'admin@app.local',
      password: 'admin123',
    );
    print('SUCCESS! User ID: \${response.user?.id}');
    
    // Now try fetching the agent record to test RLS
    final agent = await supabase.from('agents').select().eq('id', response.user!.id).single();
    print('SUCCESS! Agent data: $agent');
    
  } catch (e) {
    print('ERROR OCCURRED:');
    print(e.toString());
  }
}
