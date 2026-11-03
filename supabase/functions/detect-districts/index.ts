import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import * as turf from "https://esm.sh/@turf/turf@6.5.0"
import { decode } from "https://esm.sh/google-polyline@1.0.3"

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
    // Handle CORS preflight requests
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const { polyline } = await req.json()
        if (!polyline) {
            throw new Error('Polyline is required')
        }

        // Decode polyline (returns [lat, lng] pairs)
        const points = decode(polyline)

        // Fetch India Districts GeoJSON
        // Using a reliable source for India districts
        // Note: In production, consider hosting this in Supabase Storage and caching it
        const geojsonUrl = 'https://raw.githubusercontent.com/geohacker/india/master/india/district/india_district.geojson'

        // Using a cache or global variable in a real edge function isn't straightforward
        // but for this example we fetch it. Deno will cache the fetch if headers allow.
        const response = await fetch(geojsonUrl)
        if (!response.ok) {
            throw new Error('Failed to fetch GeoJSON data')
        }
        const geojson = await response.json()

        const detectedDistricts = new Map()

        // Sample points along the route (e.g., max 50 points) to keep processing time reasonable
        const sampleSize = 50
        const step = Math.max(1, Math.floor(points.length / sampleSize))

        for (let i = 0; i < points.length; i += step) {
            const [lat, lng] = points[i]
            const pt = turf.point([lng, lat]) // Turf uses [longitude, latitude]

            for (const feature of geojson.features) {
                if (turf.booleanPointInPolygon(pt, feature)) {
                    // Different GeoJSONs use different property names for district/state
                    const districtName = feature.properties.district ||
                        feature.properties.NAME_2 ||
                        feature.properties.dist_name ||
                        feature.properties.DISTRICT

                    const stateName = feature.properties.state ||
                        feature.properties.NAME_1 ||
                        feature.properties.st_name ||
                        feature.properties.STATE

                    if (districtName && !detectedDistricts.has(districtName)) {
                        detectedDistricts.set(districtName, {
                            name: districtName,
                            state: stateName,
                            location: { lat, lng }
                        })
                    }
                    break // Move to next point once district is found
                }
            }
        }

        const results = Array.from(detectedDistricts.values())

        return new Response(
            JSON.stringify({ districts: results }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    } catch (error) {
        console.error('Error:', error.message)
        return new Response(
            JSON.stringify({ error: error.message }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }
})
