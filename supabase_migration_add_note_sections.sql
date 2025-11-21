-- Migration: Add note_sections table to support separate sections within notes
-- This allows users to save multiple separate sections under the same note title

CREATE TABLE IF NOT EXISTS public.note_sections (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  note_id uuid NOT NULL,
  content text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT note_sections_pkey PRIMARY KEY (id),
  CONSTRAINT note_sections_note_id_fkey FOREIGN KEY (note_id) REFERENCES public.notes(id) ON DELETE CASCADE
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS note_sections_note_id_idx ON public.note_sections(note_id);
CREATE INDEX IF NOT EXISTS note_sections_created_at_idx ON public.note_sections(created_at DESC);

-- Enable RLS
ALTER TABLE public.note_sections ENABLE ROW LEVEL SECURITY;

-- RLS Policies for note_sections
-- Users can only see their own note sections
CREATE POLICY "Users can view their own note sections"
  ON public.note_sections
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.notes
      WHERE notes.id = note_sections.note_id
      AND notes.user_id = auth.uid()
    )
  );

-- Users can insert sections for their own notes
CREATE POLICY "Users can insert sections to their own notes"
  ON public.note_sections
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.notes
      WHERE notes.id = note_sections.note_id
      AND notes.user_id = auth.uid()
    )
  );

-- Users can update sections in their own notes
CREATE POLICY "Users can update sections in their own notes"
  ON public.note_sections
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.notes
      WHERE notes.id = note_sections.note_id
      AND notes.user_id = auth.uid()
    )
  );

-- Users can delete sections from their own notes
CREATE POLICY "Users can delete sections from their own notes"
  ON public.note_sections
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.notes
      WHERE notes.id = note_sections.note_id
      AND notes.user_id = auth.uid()
    )
  );

