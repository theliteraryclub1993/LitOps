const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://gqmyqrnbmutxhjjelhhb.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdxbXlxcm5ibXV0eGhqamVsaGhiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE0NTA0OTIsImV4cCI6MjA5NzAyNjQ5Mn0.9r0Kgy-ghpwvyYSco_va5VcWzpJbH9aYoz11BoFKinI';

const supabase = createClient(supabaseUrl, supabaseKey);

async function testConnection() {
  console.log('Testing connection to Supabase...');
  
  const tables = [
    // Base Schema Tables (25)
    'profiles',
    'student_master',
    'student_database_backups',
    'database_import_history',
    'events',
    'event_assignments',
    'participation_constraints',
    'teams',
    'registrations',
    'team_members',
    'waiting_list',
    'attendance',
    'event_rounds',
    'round_scores',
    'results',
    'certificates',
    'feedback',
    'appeals',
    'sarvottam_points',
    'audit_logs',
    'announcements',
    'incidents',
    'gallery',
    'notifications',
    'offline_sync_queue',

    // Extension Schema Tables (12)
    'roles',
    'permissions',
    'role_permissions',
    'member_assignments',
    'yearly_archives',
    'yearly_imports',
    'audit_extended',
    'department_rankings',
    'event_points',
    'event_schedules',
    'barcode_logs',
    'search_history'
  ];

  const results = {
    exists: [],
    missing: []
  };

  for (const table of tables) {
    try {
      const { error } = await supabase
        .from(table)
        .select('*')
        .limit(1);
      
      if (error) {
        if (error.message.includes('Could not find the table') || error.code === '42P01') {
          results.missing.push(table);
        } else {
          // Table exists but maybe permission error or empty check worked
          results.exists.push(table);
        }
      } else {
        results.exists.push(table);
      }
    } catch (err) {
      results.missing.push(table);
    }
  }

  console.log('\n--- DATABASE INSPECTION REPORT ---');
  console.log(`\nExisting Tables (${results.exists.length}):`);
  results.exists.forEach(t => console.log(`[✓] ${t}`));

  console.log(`\nMissing Tables (${results.missing.length}):`);
  results.missing.forEach(t => console.log(`[✗] ${t}`));

  // Test RPC global_search
  try {
    console.log('\nTesting global_search RPC...');
    const { data, error } = await supabase.rpc('global_search', {
      search_query: 'test',
      max_results: 5
    });

    if (error) {
      console.log('[✗] RPC global_search: NOT FOUND or ERROR -', error.message);
    } else {
      console.log('[✓] RPC global_search: ACTIVE');
    }
  } catch (err) {
    console.log('[✗] RPC global_search: FAILED -', err.message);
  }
}

testConnection();

