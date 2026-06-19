import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.8';

Deno.serve(async (req) => {
  try {
    const { record } = await req.json();
    if (!record) {
      return new Response(JSON.stringify({ error: 'Missing record' }), { status: 400 });
    }

    const userId = record.user_id;
    const title = record.title || 'New Notification';
    const message = record.message || '';
    const payloadId = record.id;

    // Initialize Supabase Client using local environment variables
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Fetch FCM tokens for this user
    const { data: tokens, error: tokenErr } = await supabase
      .from('user_fcm_tokens')
      .select('fcm_token')
      .eq('user_id', userId);

    if (tokenErr) throw tokenErr;
    if (!tokens || tokens.length === 0) {
      return new Response(JSON.stringify({ message: 'No registered tokens for user' }), { status: 200 });
    }

    // Load Firebase Service Account Credentials from Env Variables
    const credentialsRaw = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
    if (!credentialsRaw) {
      return new Response(JSON.stringify({ error: 'FIREBASE_SERVICE_ACCOUNT env var not set' }), { status: 500 });
    }

    const credentials = JSON.parse(credentialsRaw);
    const clientEmail = credentials.client_email;
    const privateKey = credentials.private_key;
    const projectId = credentials.project_id;

    // Generate Google OAuth2 Token
    const accessToken = await getAccessToken(clientEmail, privateKey);

    // Send push notification to all devices
    const results = [];
    for (const t of tokens) {
      const fcmToken = t.fcm_token;
      
      const body = {
        message: {
          token: fcmToken,
          notification: {
            title: title,
            body: message
          },
          data: {
            id: payloadId || ''
          },
          android: {
            priority: 'high',
            notification: {
              sound: 'default',
              icon: 'ic_launcher',
              color: '#FF6A2C' // your ember color!
            }
          },
          apns: {
            payload: {
              aps: {
                sound: 'default',
                badge: 1
              }
            }
          }
        }
      };

      const fcmResponse = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${accessToken}`
        },
        body: JSON.stringify(body)
      });

      const resData = await fcmResponse.json();
      results.push({ token: fcmToken, success: fcmResponse.ok, response: resData });

      // If token is invalid/not registered, clean it up from the database automatically
      if (!fcmResponse.ok && (resData.error?.status === 'UNREGISTERED' || resData.error?.message?.includes('not registered'))) {
        await supabase
          .from('user_fcm_tokens')
          .delete()
          .eq('fcm_token', fcmToken);
      }
    }

    return new Response(JSON.stringify({ results }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200
    });

  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { 'Content-Type': 'application/json' },
      status: 500
    });
  }
});

async function getAccessToken(clientEmail: string, privateKey: string): Promise<string> {
  const cleanKey = privateKey
    .replace(/\\n/g, '\n')
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '');

  const keyBuffer = Uint8Array.from(atob(cleanKey), c => c.charCodeAt(0));
  
  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    keyBuffer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  );

  const header = { alg: 'RS256', typ: 'JWT' };
  const now = Math.floor(Date.now() / 1000);
  const claim = {
    iss: clientEmail,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    exp: now + 3600,
    iat: now
  };

  const textEncoder = new TextEncoder();
  const encodedHeader = btoa(JSON.stringify(header)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
  const encodedClaim = btoa(JSON.stringify(claim)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
  const signatureInput = `${encodedHeader}.${encodedClaim}`;

  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    textEncoder.encode(signatureInput)
  );

  const encodedSignature = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');

  const jwt = `${signatureInput}.${encodedSignature}`;

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt
    })
  });

  const data = await response.json();
  if (data.error) {
    throw new Error(`Google Auth OAuth2 Error: ${data.error_description || data.error}`);
  }
  return data.access_token;
}
