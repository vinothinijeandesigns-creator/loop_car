-- ============================================================
-- LOOPCAR SUPABASE DATABASE SETUP
-- Run this entire script in Supabase SQL Editor
-- Go to: Dashboard → SQL Editor → New Query → Paste & Run
-- ============================================================

-- ============================================================
-- STEP 1: ENABLE REQUIRED EXTENSIONS
-- ============================================================

-- Enable earthdistance for location-based search
CREATE EXTENSION IF NOT EXISTS cube;
CREATE EXTENSION IF NOT EXISTS earthdistance;

-- ============================================================
-- STEP 2: CREATE PROFILES TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  mobile TEXT NOT NULL,
  dob DATE NOT NULL,
  avatar_url TEXT,
  is_driver BOOLEAN DEFAULT FALSE,
  is_verified BOOLEAN DEFAULT FALSE,
  rating_avg DECIMAL(2,1) DEFAULT 0.0,
  total_rides INTEGER DEFAULT 0,
  commitment_accepted BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_profiles_email ON public.profiles(email);
CREATE INDEX IF NOT EXISTS idx_profiles_mobile ON public.profiles(mobile);

-- ============================================================
-- STEP 3: CREATE VEHICLES TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.vehicles (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  make TEXT NOT NULL,
  model TEXT NOT NULL,
  color TEXT NOT NULL,
  plate_number TEXT UNIQUE NOT NULL,
  vehicle_type TEXT NOT NULL CHECK (vehicle_type IN ('sedan', 'suv', 'hatchback', 'van', 'bike')),
  total_seats INTEGER NOT NULL CHECK (total_seats BETWEEN 1 AND 8),
  is_verified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;

-- Create index
CREATE INDEX IF NOT EXISTS idx_vehicles_user ON public.vehicles(user_id);

-- ============================================================
-- STEP 4: CREATE RIDES TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.rides (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  driver_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  vehicle_id UUID REFERENCES public.vehicles(id) ON DELETE SET NULL,
  
  -- Location details
  start_location TEXT NOT NULL,
  start_lat DOUBLE PRECISION NOT NULL,
  start_lng DOUBLE PRECISION NOT NULL,
  end_location TEXT NOT NULL,
  end_lat DOUBLE PRECISION NOT NULL,
  end_lng DOUBLE PRECISION NOT NULL,
  
  -- Ride details
  departure_datetime TIMESTAMPTZ NOT NULL,
  available_seats INTEGER NOT NULL CHECK (available_seats BETWEEN 0 AND 8),
  price_per_seat DECIMAL(10, 2) NOT NULL CHECK (price_per_seat >= 0),
  
  -- Preferences
  music_allowed BOOLEAN DEFAULT TRUE,
  smoking_allowed BOOLEAN DEFAULT FALSE,
  pets_allowed BOOLEAN DEFAULT FALSE,
  luggage_size TEXT DEFAULT 'small' CHECK (luggage_size IN ('none', 'small', 'medium', 'large')),
  
  -- Status
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'full', 'in_progress', 'completed', 'cancelled')),
  notes TEXT,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.rides ENABLE ROW LEVEL SECURITY;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_rides_driver ON public.rides(driver_id);
CREATE INDEX IF NOT EXISTS idx_rides_departure ON public.rides(departure_datetime);
CREATE INDEX IF NOT EXISTS idx_rides_status ON public.rides(status);
CREATE INDEX IF NOT EXISTS idx_rides_start_coords ON public.rides(start_lat, start_lng);
CREATE INDEX IF NOT EXISTS idx_rides_end_coords ON public.rides(end_lat, end_lng);

-- ============================================================
-- STEP 5: CREATE BOOKINGS TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.bookings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  ride_id UUID REFERENCES public.rides(id) ON DELETE CASCADE NOT NULL,
  passenger_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  seats_booked INTEGER NOT NULL CHECK (seats_booked BETWEEN 1 AND 4),
  total_price DECIMAL(10, 2) NOT NULL,
  
  -- Pickup/Drop customization
  pickup_location TEXT,
  pickup_lat DOUBLE PRECISION,
  pickup_lng DOUBLE PRECISION,
  dropoff_location TEXT,
  dropoff_lat DOUBLE PRECISION,
  dropoff_lng DOUBLE PRECISION,
  
  -- Status
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'cancelled', 'completed')),
  payment_status TEXT DEFAULT 'unpaid' CHECK (payment_status IN ('unpaid', 'paid', 'refunded')),
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Prevent duplicate bookings
  UNIQUE(ride_id, passenger_id)
);

-- Enable RLS
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_bookings_ride ON public.bookings(ride_id);
CREATE INDEX IF NOT EXISTS idx_bookings_passenger ON public.bookings(passenger_id);
CREATE INDEX IF NOT EXISTS idx_bookings_status ON public.bookings(status);

-- ============================================================
-- STEP 6: CREATE RATINGS TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.ratings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  booking_id UUID REFERENCES public.bookings(id) ON DELETE CASCADE NOT NULL UNIQUE,
  ride_id UUID REFERENCES public.rides(id) ON DELETE CASCADE NOT NULL,
  rater_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  ratee_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  
  rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
  review TEXT,
  rating_type TEXT NOT NULL CHECK (rating_type IN ('passenger_to_driver', 'driver_to_passenger')),
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.ratings ENABLE ROW LEVEL SECURITY;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_ratings_ratee ON public.ratings(ratee_id);
CREATE INDEX IF NOT EXISTS idx_ratings_ride ON public.ratings(ride_id);

-- ============================================================
-- STEP 7: CREATE FUNCTIONS AND TRIGGERS
-- ============================================================

-- Function: Auto-create profile on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, first_name, last_name, mobile, dob)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'first_name', 'User'),
    COALESCE(NEW.raw_user_meta_data->>'last_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'mobile', ''),
    COALESCE((NEW.raw_user_meta_data->>'dob')::DATE, CURRENT_DATE)
  );
  RETURN NEW;
EXCEPTION
  WHEN others THEN
    RAISE LOG 'Error in handle_new_user: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if exists and create new
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- Function: Update available seats after booking status change
CREATE OR REPLACE FUNCTION public.update_ride_seats()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
    -- When booking is accepted, reduce seats
    IF NEW.status = 'accepted' AND (TG_OP = 'INSERT' OR OLD.status != 'accepted') THEN
      UPDATE public.rides
      SET 
        available_seats = available_seats - NEW.seats_booked,
        status = CASE 
          WHEN available_seats - NEW.seats_booked <= 0 THEN 'full'
          ELSE status
        END,
        updated_at = NOW()
      WHERE id = NEW.ride_id AND available_seats >= NEW.seats_booked;
    END IF;
    
    -- When booking is cancelled (was accepted), restore seats
    IF TG_OP = 'UPDATE' AND NEW.status = 'cancelled' AND OLD.status = 'accepted' THEN
      UPDATE public.rides
      SET 
        available_seats = available_seats + OLD.seats_booked,
        status = CASE 
          WHEN status = 'full' THEN 'active'
          ELSE status
        END,
        updated_at = NOW()
      WHERE id = OLD.ride_id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if exists and create new
DROP TRIGGER IF EXISTS on_booking_change ON public.bookings;
CREATE TRIGGER on_booking_change
  AFTER INSERT OR UPDATE ON public.bookings
  FOR EACH ROW
  EXECUTE FUNCTION public.update_ride_seats();

-- Function: Update user rating average
CREATE OR REPLACE FUNCTION public.update_user_rating()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.profiles
  SET 
    rating_avg = (
      SELECT COALESCE(ROUND(AVG(rating)::DECIMAL, 1), 0)
      FROM public.ratings
      WHERE ratee_id = NEW.ratee_id
    ),
    total_rides = (
      SELECT COUNT(DISTINCT ride_id)
      FROM public.ratings
      WHERE ratee_id = NEW.ratee_id
    ),
    updated_at = NOW()
  WHERE id = NEW.ratee_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if exists and create new
DROP TRIGGER IF EXISTS on_new_rating ON public.ratings;
CREATE TRIGGER on_new_rating
  AFTER INSERT ON public.ratings
  FOR EACH ROW
  EXECUTE FUNCTION public.update_user_rating();

-- Function: Updated at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create updated_at triggers for all tables
DROP TRIGGER IF EXISTS update_profiles_updated_at ON public.profiles;
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at();

DROP TRIGGER IF EXISTS update_vehicles_updated_at ON public.vehicles;
CREATE TRIGGER update_vehicles_updated_at
  BEFORE UPDATE ON public.vehicles
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at();

DROP TRIGGER IF EXISTS update_rides_updated_at ON public.rides;
CREATE TRIGGER update_rides_updated_at
  BEFORE UPDATE ON public.rides
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at();

DROP TRIGGER IF EXISTS update_bookings_updated_at ON public.bookings;
CREATE TRIGGER update_bookings_updated_at
  BEFORE UPDATE ON public.bookings
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at();

-- ============================================================
-- STEP 8: CREATE SEARCH RIDES FUNCTION
-- ============================================================

CREATE OR REPLACE FUNCTION public.search_rides(
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
    -- Calculate distance from search start to ride start (in km)
    ROUND((earth_distance(
      ll_to_earth(p_start_lat, p_start_lng),
      ll_to_earth(r.start_lat, r.start_lng)
    ) / 1000)::DOUBLE PRECISION, 2) AS start_distance_km,
    -- Calculate distance from search end to ride end (in km)
    ROUND((earth_distance(
      ll_to_earth(p_end_lat, p_end_lng),
      ll_to_earth(r.end_lat, r.end_lng)
    ) / 1000)::DOUBLE PRECISION, 2) AS end_distance_km
  FROM public.rides r
  INNER JOIN public.profiles p ON r.driver_id = p.id
  WHERE 
    r.status = 'active'
    AND r.available_seats >= p_seats
    AND DATE(r.departure_datetime) = p_departure_date
    -- Filter by start location radius
    AND earth_distance(
      ll_to_earth(p_start_lat, p_start_lng),
      ll_to_earth(r.start_lat, r.start_lng)
    ) / 1000 <= p_radius_km
    -- Filter by end location radius
    AND earth_distance(
      ll_to_earth(p_end_lat, p_end_lng),
      ll_to_earth(r.end_lat, r.end_lng)
    ) / 1000 <= p_radius_km
  ORDER BY 
    (earth_distance(ll_to_earth(p_start_lat, p_start_lng), ll_to_earth(r.start_lat, r.start_lng)) +
     earth_distance(ll_to_earth(p_end_lat, p_end_lng), ll_to_earth(r.end_lat, r.end_lng))) ASC,
    r.departure_datetime ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- STEP 9: CREATE ROW LEVEL SECURITY POLICIES
-- ============================================================

-- ========== PROFILES POLICIES ==========

DROP POLICY IF EXISTS "Profiles are viewable by everyone" ON public.profiles;
CREATE POLICY "Profiles are viewable by everyone"
ON public.profiles FOR SELECT
USING (true);

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile"
ON public.profiles FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Profiles created via trigger" ON public.profiles;
CREATE POLICY "Profiles created via trigger"
ON public.profiles FOR INSERT
WITH CHECK (auth.uid() = id);

-- ========== VEHICLES POLICIES ==========

DROP POLICY IF EXISTS "Vehicles are viewable by everyone" ON public.vehicles;
CREATE POLICY "Vehicles are viewable by everyone"
ON public.vehicles FOR SELECT
USING (true);

DROP POLICY IF EXISTS "Users can insert own vehicles" ON public.vehicles;
CREATE POLICY "Users can insert own vehicles"
ON public.vehicles FOR INSERT
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own vehicles" ON public.vehicles;
CREATE POLICY "Users can update own vehicles"
ON public.vehicles FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own vehicles" ON public.vehicles;
CREATE POLICY "Users can delete own vehicles"
ON public.vehicles FOR DELETE
USING (auth.uid() = user_id);

-- ========== RIDES POLICIES ==========

DROP POLICY IF EXISTS "Rides are viewable by everyone" ON public.rides;
CREATE POLICY "Rides are viewable by everyone"
ON public.rides FOR SELECT
USING (true);

DROP POLICY IF EXISTS "Users can create rides" ON public.rides;
CREATE POLICY "Users can create rides"
ON public.rides FOR INSERT
WITH CHECK (auth.uid() = driver_id);

DROP POLICY IF EXISTS "Drivers can update own rides" ON public.rides;
CREATE POLICY "Drivers can update own rides"
ON public.rides FOR UPDATE
USING (auth.uid() = driver_id)
WITH CHECK (auth.uid() = driver_id);

DROP POLICY IF EXISTS "Drivers can delete own rides" ON public.rides;
CREATE POLICY "Drivers can delete own rides"
ON public.rides FOR DELETE
USING (auth.uid() = driver_id);

-- ========== BOOKINGS POLICIES ==========

DROP POLICY IF EXISTS "Users can view own bookings" ON public.bookings;
CREATE POLICY "Users can view own bookings"
ON public.bookings FOR SELECT
USING (
  auth.uid() = passenger_id 
  OR EXISTS (
    SELECT 1 FROM public.rides 
    WHERE rides.id = bookings.ride_id 
    AND rides.driver_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Users can create bookings" ON public.bookings;
CREATE POLICY "Users can create bookings"
ON public.bookings FOR INSERT
WITH CHECK (
  auth.uid() = passenger_id
  AND auth.uid() != (SELECT driver_id FROM public.rides WHERE id = ride_id)
);

DROP POLICY IF EXISTS "Users can update bookings" ON public.bookings;
CREATE POLICY "Users can update bookings"
ON public.bookings FOR UPDATE
USING (
  auth.uid() = passenger_id 
  OR EXISTS (
    SELECT 1 FROM public.rides 
    WHERE rides.id = bookings.ride_id 
    AND rides.driver_id = auth.uid()
  )
);

-- ========== RATINGS POLICIES ==========

DROP POLICY IF EXISTS "Ratings are viewable by everyone" ON public.ratings;
CREATE POLICY "Ratings are viewable by everyone"
ON public.ratings FOR SELECT
USING (true);

DROP POLICY IF EXISTS "Users can create ratings" ON public.ratings;
CREATE POLICY "Users can create ratings"
ON public.ratings FOR INSERT
WITH CHECK (
  auth.uid() = rater_id
  AND EXISTS (
    SELECT 1 FROM public.bookings b
    INNER JOIN public.rides r ON b.ride_id = r.id
    WHERE b.id = booking_id
    AND b.status = 'completed'
    AND (
      (auth.uid() = b.passenger_id AND ratee_id = r.driver_id)
      OR (auth.uid() = r.driver_id AND ratee_id = b.passenger_id)
    )
  )
);

-- ============================================================
-- SETUP COMPLETE!
-- ============================================================

-- Verify tables were created
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_type = 'BASE TABLE'
ORDER BY table_name;
