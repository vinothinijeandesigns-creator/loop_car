-- ============================================================
-- LOOPCAR CHAT FEATURE SETUP
-- Run this script in Supabase SQL Editor to create chat tables
-- ============================================================

-- 1. Create chat_threads table
CREATE TABLE IF NOT EXISTS public.chat_threads (
  id TEXT PRIMARY KEY, -- Format: rideId_passengerId
  ride_id UUID REFERENCES public.rides(id) ON DELETE CASCADE,
  participant1_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE, -- Usually Driver
  participant2_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE, -- Usually Passenger
  last_message TEXT,
  last_time TIMESTAMPTZ DEFAULT NOW(),
  unread_p1 INTEGER DEFAULT 0,
  unread_p2 INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.chat_threads ENABLE ROW LEVEL SECURITY;

-- Index for fast queries on participant threads
CREATE INDEX IF NOT EXISTS idx_chat_threads_p1 ON public.chat_threads(participant1_id);
CREATE INDEX IF NOT EXISTS idx_chat_threads_p2 ON public.chat_threads(participant2_id);
CREATE INDEX IF NOT EXISTS idx_chat_threads_ride ON public.chat_threads(ride_id);

-- RLS for threads: Users can only select/update their own threads
DROP POLICY IF EXISTS "Users can view their chat threads" ON public.chat_threads;
CREATE POLICY "Users can view their chat threads"
ON public.chat_threads FOR SELECT
USING (auth.uid() = participant1_id OR auth.uid() = participant2_id);

DROP POLICY IF EXISTS "Users can create their chat threads" ON public.chat_threads;
CREATE POLICY "Users can create their chat threads"
ON public.chat_threads FOR INSERT
WITH CHECK (auth.uid() = participant1_id OR auth.uid() = participant2_id);

DROP POLICY IF EXISTS "Users can update their chat threads" ON public.chat_threads;
CREATE POLICY "Users can update their chat threads"
ON public.chat_threads FOR UPDATE
USING (auth.uid() = participant1_id OR auth.uid() = participant2_id);


-- 2. Create chat_messages table
CREATE TABLE IF NOT EXISTS public.chat_messages (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  thread_id TEXT REFERENCES public.chat_threads(id) ON DELETE CASCADE NOT NULL,
  sender_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  text TEXT NOT NULL,
  is_system_message BOOLEAN DEFAULT FALSE,
  is_seen BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

-- Index for fetching messages by thread
CREATE INDEX IF NOT EXISTS idx_chat_messages_thread ON public.chat_messages(thread_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_created_at ON public.chat_messages(created_at);

-- RLS for messages: Must be a participant in the thread to read/insert
DROP POLICY IF EXISTS "Users can view messages in their threads" ON public.chat_messages;
CREATE POLICY "Users can view messages in their threads"
ON public.chat_messages FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.chat_threads t
    WHERE t.id = thread_id
    AND (t.participant1_id = auth.uid() OR t.participant2_id = auth.uid())
  )
);

DROP POLICY IF EXISTS "Users can insert messages in their threads" ON public.chat_messages;
CREATE POLICY "Users can insert messages in their threads"
ON public.chat_messages FOR INSERT
WITH CHECK (
  (auth.uid() = sender_id OR sender_id IS NULL)
  AND EXISTS (
    SELECT 1 FROM public.chat_threads t
    WHERE t.id = thread_id
    AND (t.participant1_id = auth.uid() OR t.participant2_id = auth.uid())
  )
);

DROP POLICY IF EXISTS "Users can update their messages" ON public.chat_messages;
CREATE POLICY "Users can update their messages"
ON public.chat_messages FOR UPDATE
USING (auth.uid() = sender_id);


-- 3. Trigger to update last_message and unread counts when a new message is inserted
CREATE OR REPLACE FUNCTION public.update_thread_on_new_message()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.chat_threads
  SET 
    last_message = NEW.text,
    last_time = NEW.created_at,
    -- Increment unread count for the other participant
    unread_p1 = CASE WHEN NEW.sender_id = participant2_id THEN unread_p1 + 1 ELSE unread_p1 END,
    unread_p2 = CASE WHEN NEW.sender_id = participant1_id THEN unread_p2 + 1 ELSE unread_p2 END,
    updated_at = NOW()
  WHERE id = NEW.thread_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_new_chat_message ON public.chat_messages;
CREATE TRIGGER on_new_chat_message
  AFTER INSERT ON public.chat_messages
  FOR EACH ROW
  EXECUTE FUNCTION public.update_thread_on_new_message();


-- 4. Set up updated_at trigger for chat_threads
DROP TRIGGER IF EXISTS update_chat_threads_updated_at ON public.chat_threads;
CREATE TRIGGER update_chat_threads_updated_at
  BEFORE UPDATE ON public.chat_threads
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at();

-- Verify setup
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' AND table_name LIKE 'chat_%';

-- 5. Enable Realtime for the new tables
-- This is strictly required for Flutter's .stream() to work!
ALTER PUBLICATION supabase_realtime ADD TABLE chat_threads;
ALTER PUBLICATION supabase_realtime ADD TABLE chat_messages;
