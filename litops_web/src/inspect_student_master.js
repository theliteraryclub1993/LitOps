const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://gqmyqrnbmutxhjjelhhb.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdxbXlxcm5ibXV0eGhqamVsaGhiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE0NTA0OTIsImV4cCI6MjA5NzAyNjQ5Mn0.9r0Kgy-ghpwvyYSco_va5VcWzpJbH9aYoz11BoFKinI';

const supabase = createClient(supabaseUrl, supabaseKey, {
  auth: {
    persistSession: false
  }
});

async function main() {
  console.log('Logging in...');
  const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
    email: 'theliteraryclubmce@gmail.com',
    password: 'Malnad2K27'
  });

  if (authError) {
    console.error('Authentication failed:', authError.message);
    return;
  }

  console.log('Logged in successfully!');

  console.log('Querying student_master...');
  const { data, error } = await supabase
    .from('student_master')
    .select('*')
    .limit(1);

  if (error) {
    console.error('Error querying student_master:', error);
  } else {
    console.log('Student master sample row:', data);
  }
}

main().catch(console.error);
