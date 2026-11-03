const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://usysfcfncfiwdqpqzije.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVzeXNmY2ZuY2Zpd2RxcHF6aWplIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk0MDc2OTMsImV4cCI6MjA4NDk4MzY5M30.XafXkazhRb9wDqJZSNb27z9G3WRRboHmZatDIMFrRDs';

const supabase = createClient(supabaseUrl, supabaseKey);

async function testFunction() {
  console.log("Fetching users from profiles...");
  const { data: profiles, error: pError } = await supabase.from('profiles').select('*');
  if (pError) {
    console.error("Error fetching profiles:", pError);
    return;
  }
  
  const magathi = profiles.find(p => p.email === 'magathi@gmail.com');
  console.log("Magathi profile FCM Token:", magathi ? magathi.fcm_token : 'Not found');

  if (!magathi) {
      console.log("Could not find magathi");
      return;
  }

  console.log("Invoking edge function for Magathi...");
  const { data, error } = await supabase.functions.invoke('send-notification', {
    body: { 
        userId: magathi.id, 
        title: "Test", 
        message: "This is a test notification" 
    }
  });

  console.log("Edge Function Response Data:", data);
  console.log("Edge Function Error:", error);
}

testFunction();
