const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://gqmyqrnbmutxhjjelhhb.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdxbXlxcm5ibXV0eGhqamVsaGhiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE0NTA0OTIsImV4cCI6MjA5NzAyNjQ5Mn0.9r0Kgy-ghpwvyYSco_va5VcWzpJbH9aYoz11BoFKinI';

const supabase = createClient(supabaseUrl, supabaseKey, {
  auth: {
    persistSession: false
  }
});

async function main() {
  console.log('Logging in as super admin...');
  const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
    email: 'theliteraryclubmce@gmail.com',
    password: 'Malnad2K27'
  });

  if (authError) {
    console.error('Authentication failed:', authError.message);
    return;
  }

  const userId = authData.user.id;
  console.log('Successfully logged in! User ID:', userId);

  // 1. Fetch super admin profile
  console.log('Fetching super admin profile...');
  const { data: adminProfile, error: profileError } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', userId)
    .single();

  if (profileError) {
    console.error('Failed to fetch admin profile:', profileError.message);
    return;
  }

  console.log('Super Admin Profile:', JSON.stringify(adminProfile, null, 2));

  // 2. Fetch another profile to attempt update
  console.log('Fetching another profile to update...');
  const { data: otherProfiles, error: othersError } = await supabase
    .from('profiles')
    .select('*')
    .neq('id', userId)
    .limit(1);

  if (othersError) {
    console.error('Failed to fetch other profiles:', othersError.message);
    return;
  }

  if (otherProfiles.length === 0) {
    console.log('No other profiles found in database.');
    return;
  }

  const targetUser = otherProfiles[0];
  console.log('Target user for update:', targetUser.email, 'ID:', targetUser.id);

  // 3. Attempt to update target user
  console.log('Attempting update (changing full_name)...');
  const originalName = targetUser.full_name;
  const testName = originalName + ' (Test Update)';
  
  const { data: updateData, error: updateError } = await supabase
    .from('profiles')
    .update({ full_name: testName })
    .eq('id', targetUser.id)
    .select();

  if (updateError) {
    console.error('Update FAILED with error:', updateError);
  } else {
    console.log('Update SUCCEEDED! Result:', updateData);
    
    // Revert the update
    console.log('Reverting update...');
    const { error: revertError } = await supabase
      .from('profiles')
      .update({ full_name: originalName })
      .eq('id', targetUser.id);
      
    if (revertError) {
      console.error('Revert failed:', revertError.message);
    } else {
      console.log('Revert succeeded!');
    }
  }
}

main().catch(console.error);
