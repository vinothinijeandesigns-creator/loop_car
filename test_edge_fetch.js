const supabaseUrl = 'https://usysfcfncfiwdqpqzije.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVzeXNmY2ZuY2Zpd2RxcHF6aWplIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk0MDc2OTMsImV4cCI6MjA4NDk4MzY5M30.XafXkazhRb9wDqJZSNb27z9G3WRRboHmZatDIMFrRDs';

async function testFunction() {
  console.log("Fetching users from profiles...");
  
  const profilesRes = await fetch(`${supabaseUrl}/rest/v1/profiles`, {
    headers: {
        'apikey': supabaseKey,
        'Authorization': `Bearer ${supabaseKey}`
    }
  });
  
  const profiles = await profilesRes.json();
  const magathi = profiles.find(p => p.email === 'magathi@gmail.com');
  console.log("Magathi profile FCM Token:", magathi ? magathi.fcm_token : 'Not found');

  if (!magathi) {
      console.log("Could not find magathi");
      return;
  }

  console.log("Invoking edge function for Magathi (ID: " + magathi.id + ")...");
  
  const funcRes = await fetch(`${supabaseUrl}/functions/v1/send-notification`, {
      method: 'POST',
      headers: {
        'apikey': supabaseKey,
        'Authorization': `Bearer ${supabaseKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
          userId: magathi.id,
          title: "Test",
          message: "This is a test notification"
      })
  });
  
  const text = await funcRes.text();
  console.log("Edge Function Status:", funcRes.status);
  console.log("Edge Function Response:", text);
}

testFunction();
