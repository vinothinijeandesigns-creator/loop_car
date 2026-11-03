$headers = @{ 
  'apikey' = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVzeXNmY2ZuY2Zpd2RxcHF6aWplIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk0MDc2OTMsImV4cCI6MjA4NDk4MzY5M30.XafXkazhRb9wDqJZSNb27z9G3WRRboHmZatDIMFrRDs'
  'Authorization' = 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVzeXNmY2ZuY2Zpd2RxcHF6aWplIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk0MDc2OTMsImV4cCI6MjA4NDk4MzY5M30.XafXkazhRb9wDqJZSNb27z9G3WRRboHmZatDIMFrRDs'
}
Invoke-RestMethod -Uri 'https://usysfcfncfiwdqpqzije.supabase.co/rest/v1/rides?select=*' -Headers $headers | ConvertTo-Json -Depth 10
