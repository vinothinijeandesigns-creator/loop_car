import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'npm:@supabase/supabase-js@2'
import { JWT } from 'npm:google-auth-library@9'

// Firebase-ல் Service Accounts -> "Generate new private key" செய்து டவுன்லோட் ஆகும் JSON ஃபைலின் உள்ளடக்கத்தை இங்கே போடவும்
const serviceAccount = {
  "type": "service_account",
  "project_id": "loopcar-1784e", // இதை உங்கள் project_id-ஆக மாற்றவும்
  "private_key_id": "c1660c9e9ae08c4e591d8387c1de79ef282fefa7",
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDSt1phs3SajcfC\nARwxgEIUtb5Ocdw5HuVPB4zZmScJjv3OeHivFpNn47ogvGbD/IdogFKIBCqhRkVw\nJm1HtHc8hzZhVxamU8Iczds4IUK5C9tBcmxKQJj6tEvL1ESCedduGh8ajw0SYx0D\nK9Ibfs66rAuSyr578qGWovDsrLiwt1pHnOYprPpCxXvSrZSzstLGkLVTCVLIQhNR\nkBMsgiY2W1myNb0kGXqWp/BnMegfEzFFj1aOHluWogMOBTQs7IUtHbOSD+C/mpAq\n886YKNKVHPrFvVWcaLf0+tkdecM/78Ge1+V2KL60jz1fP52HsVjRt+WOSCHB4LAE\nnIRTsg+pAgMBAAECggEAXjK0V1/jnSILrmlTordtExgKOsRAyFJM/Y7pAu+p2WaQ\nhOgrP05u2C8gKnk+0ZeHKwrOmlqOeilRamjrSnZdJXRmtY46pGFmMf0+5nFMBDBO\nNIxD58/H8699AOJkPBXe3iwUQom3tMQVGLFSzJLcNOwrglRbYkqdvRsbbBpsuCZ3\nkNzT2fH5h/eSGZmeTAEc0fmbI9pUTswUMDibvBmgQbqpecs9IWIQR08jJl/4l+v/\nFfQsFtfGTL0uy5fuSLs8h0c7HJmEyOKLpkTawovg+WQu1B1Et05CCV8DrQCx/T8d\nfTTf3WPAzDDic/ROD+Z+onK23QjD1oV0j5vnqN1fvwKBgQDwQyiZ4S8AhiKHeznm\nXXqvqDqSApciYtR0tqAhRCINywneMYMEsiWpunSt6zrpaYdAI1PwJRRR9lSFbMu7\nneJpaPWyzVcr0oUrJjBX0yaNt9dSeTsIhwHCR61a9J+wNV0sjZadBscOKmNcWkhy\nPSXcpUtRHu5ag97xCyDNfdna/wKBgQDghMAIQp8oeOdI3L40F4Mfl4upRqxEzpPI\nXHrvfEioN2yhIy/mpnu2HCvl+bmD2aar1n5eBq+iMMxD02rrh/8cBzsYrC4KeLD0\nupdoLrOs5ECZwIABJ5GQGx7rTP49peW9QTkhO/4h1iD36OxVewbgrqkCPPrMRLXr\n9zYxV+ZdVwKBgF9H4uQTf1ZP24WrAq0uySa8Km4ZBOKoGuUmP56xrGeX65PoQrMs\nCu+id/842CYUqYRv/iuwKLzQWXiISstes5ll/HoqILXKSPFxtZ4+qH1vOL8GQLkD\nAVmQn1kAxgtVPlwa0m33cB1YBgtr6msTgN5d1t6Wy6OtxE4HQbz8edb1AoGAa5y1\nPkBQcOGiWbYUJHuwiY/ljPkm0MQC6WIKOodje9003/cxmmfpm9vc3pnXZW8JCAwC\n/aZOwHqLLWdENCg3CoQcuzKrzrESf/p/X5wi2pd8rzUpJWSFzIBzTWzV306I0zFT\n5K4QnL85hhnKTR5uqXqN31jDDO1SFQukmfn7nHkCgYEA5Un47EAvPU7ZQv5BbHfj\n8w4pLA9DcDL9oGEDznCjgX9d4clLnP3pXbeDPeoLVJd+ef+X2W4Azjf3AjkG4vCt\nc+qulSdxDLE6AoBPY9XT9+zJ60LPOlJEvpZNB1SAv0T6hO3sc2us+669VYylrtAX\n8fpJYmlw4xI92vIhTmOiU0g=\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk-fbsvc@loopcar-1784e.iam.gserviceaccount.com",
  "client_id": "117974669455371715756",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40loopcar-1784e.iam.gserviceaccount.com",
  "client_x509_cert_url": "..."
}

serve(async (req: Request) => {
  try {
    const { userId, title, message } = await req.json()

    // 1. Supabase Client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 2. FCM Token From DB
    const { data: profile } = await supabaseClient
      .from('profiles')
      .select('fcm_token')
      .eq('id', userId)
      .single()

    const fcmToken = profile?.fcm_token
    if (!fcmToken) {
      return new Response(JSON.stringify({ error: 'User does not have an FCM token' }), { status: 400 })
    }

    // 3. Generate OAuth2 Token
    const jwtClient = new JWT({
      email: serviceAccount.client_email,
      key: serviceAccount.private_key,
      scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
    })
    const tokens = await jwtClient.authorize()

    // 4. Send FCM Push Notification
    const fcmPayload = {
      message: {
        token: fcmToken,
        notification: {
          title: title,
          body: message,
        },
      },
    }

    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${tokens.access_token}`,
        },
        body: JSON.stringify(fcmPayload),
      }
    )

    const resData = await res.json()
    if (!res.ok) {
      throw new Error(JSON.stringify(resData))
    }

    return new Response(JSON.stringify({ success: true, message: 'Notification Sent!' }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }
})
