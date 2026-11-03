-- ============================================================
-- ADVANCED RIDE SEARCH (SQL for Supabase)
-- Handles searches that match Start Point, End Point, OR Stopovers.
-- ============================================================

-- 1. Create the ride_stops table first if it doesn't exist
CREATE TABLE IF NOT EXISTS public.ride_stops (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  ride_id UUID REFERENCES public.rides(id) ON DELETE CASCADE NOT NULL,
  location_name TEXT NOT NULL,
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  stop_order INTEGER NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS and indexes
ALTER TABLE public.ride_stops ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_ride_stops_ride_id ON public.ride_stops(ride_id);
CREATE INDEX IF NOT EXISTS idx_ride_stops_coords ON public.ride_stops(lat, lng);

-- Policy: Everyone can view stops
CREATE POLICY "Stops are viewable by everyone" ON public.ride_stops FOR SELECT USING (true);

-- Policy: Drivers can insert stops for their rides
CREATE POLICY "Drivers can insert stops for their rides" 
ON public.ride_stops FOR INSERT 
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.rides 
    WHERE id = ride_id AND driver_id = auth.uid()
  )
);

-- Policy: Drivers can update stops for their rides
CREATE POLICY "Drivers can update stops for their rides" 
ON public.ride_stops FOR UPDATE 
USING (
  EXISTS (
    SELECT 1 FROM public.rides 
    WHERE id = ride_id AND driver_id = auth.uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.rides 
    WHERE id = ride_id AND driver_id = auth.uid()
  )
);

-- Policy: Drivers can delete stops for their rides
CREATE POLICY "Drivers can delete stops for their rides" 
ON public.ride_stops FOR DELETE 
USING (
  EXISTS (
    SELECT 1 FROM public.rides 
    WHERE id = ride_id AND driver_id = auth.uid()
  )
);

-- 2. Advanced Search Function
CREATE OR REPLACE FUNCTION public.search_rides_advanced(
  p_start_lat DOUBLE PRECISION,
  p_start_lng DOUBLE PRECISION,
  p_end_lat DOUBLE PRECISION,
  p_end_lng DOUBLE PRECISION,
  p_departure_date DATE,
  p_seats INTEGER DEFAULT 1,
  p_radius_km DOUBLE PRECISION DEFAULT 15.0
)
RETURNS TABLE (
  ride_id UUID,
  driver_id UUID,
  driver_first_name TEXT,
  driver_last_name TEXT,
  driver_avatar TEXT,
  driver_rating DECIMAL,
  start_location TEXT,
  end_location TEXT,
  start_lat DOUBLE PRECISION,
  start_lng DOUBLE PRECISION,
  end_lat DOUBLE PRECISION,
  end_lng DOUBLE PRECISION,
  departure_datetime TIMESTAMPTZ,
  available_seats INTEGER,
  price_per_seat DECIMAL,
  music_allowed BOOLEAN,
  smoking_allowed BOOLEAN,
  pets_allowed BOOLEAN,
  start_distance_km DOUBLE PRECISION,
  end_distance_km DOUBLE PRECISION
) AS $$
BEGIN
  RETURN QUERY
  WITH matched_starts AS (
    -- Matches either the main start location OR an intermediate stopover
    SELECT r.id as ride_id, 0 as stop_order, 
           earth_distance(ll_to_earth(p_start_lat, p_start_lng), ll_to_earth(r.start_lat, r.start_lng)) / 1000 as dist
    FROM public.rides r
    WHERE earth_distance(ll_to_earth(p_start_lat, p_start_lng), ll_to_earth(r.start_lat, r.start_lng)) / 1000 <= p_radius_km
    
    UNION ALL
    
    SELECT rs.ride_id, rs.stop_order + 1,
           earth_distance(ll_to_earth(p_start_lat, p_start_lng), ll_to_earth(rs.lat, rs.lng)) / 1000 as dist
    FROM public.ride_stops rs
    WHERE earth_distance(ll_to_earth(p_start_lat, p_start_lng), ll_to_earth(rs.lat, rs.lng)) / 1000 <= p_radius_km
  ),
  matched_ends AS (
    -- Matches either an intermediate stopover OR the main end location
    SELECT rs.ride_id, rs.stop_order + 1 as stop_order,
           earth_distance(ll_to_earth(p_end_lat, p_end_lng), ll_to_earth(rs.lat, rs.lng)) / 1000 as dist
    FROM public.ride_stops rs
    WHERE earth_distance(ll_to_earth(p_end_lat, p_end_lng), ll_to_earth(rs.lat, rs.lng)) / 1000 <= p_radius_km
    
    UNION ALL
    
    SELECT r.id as ride_id, 999 as stop_order,
           earth_distance(ll_to_earth(p_end_lat, p_end_lng), ll_to_earth(r.end_lat, r.end_lng)) / 1000 as dist
    FROM public.rides r
    WHERE earth_distance(ll_to_earth(p_end_lat, p_end_lng), ll_to_earth(r.end_lat, r.end_lng)) / 1000 <= p_radius_km
  )
  SELECT 
    r.id AS ride_id,
    r.driver_id,
    p.first_name AS driver_first_name,
    p.last_name AS driver_last_name,
    p.avatar_url AS driver_avatar,
    p.rating_avg AS driver_rating,
    r.start_location,
    r.end_location,
    r.start_lat,
    r.start_lng,
    r.end_lat,
    r.end_lng,
    r.departure_datetime,
    r.available_seats,
    r.price_per_seat,
    r.music_allowed,
    r.smoking_allowed,
    r.pets_allowed,
    s.dist AS start_distance_km,
    e.dist AS end_distance_km
  FROM public.rides r
  INNER JOIN public.profiles p ON r.driver_id = p.id
  INNER JOIN matched_starts s ON r.id = s.ride_id
  INNER JOIN matched_ends e ON r.id = e.ride_id
  WHERE 
    r.status = 'active'
    AND r.available_seats >= p_seats
    AND DATE(r.departure_datetime) = p_departure_date
    AND s.stop_order < e.stop_order -- Ensures start is before end in the journey
  ORDER BY 
    (s.dist + e.dist) ASC,
    r.departure_datetime ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
