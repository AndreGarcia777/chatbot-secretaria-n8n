CREATE TABLE public.clinics (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  whatsapp_number text UNIQUE NOT NULL,
  address text,
  business_hours jsonb DEFAULT '{}'::jsonb,
  accepted_insurances text[] DEFAULT '{}',
  bot_prompt text,
  human_agent_number text,
  created_at timestamptz DEFAULT now()
);

COMMENT ON TABLE public.clinics IS 'Tabela de configuração Single-Tenant Lite. Cada registro = 1 clínica.';

CREATE TABLE public.doctors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id uuid NOT NULL REFERENCES public.clinics(id) ON DELETE CASCADE,
  name text NOT NULL,
  specialty text NOT NULL,
  active boolean DEFAULT true,
  consultation_price numeric(10,2),
  created_at timestamptz DEFAULT now()
);

CREATE TABLE public.patients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id uuid NOT NULL REFERENCES public.clinics(id) ON DELETE CASCADE,
  whatsapp_number text NOT NULL,
  name text,
  insurance text,
  cpf_last4 text CHECK (cpf_last4 ~ '^\d{4}$'),
  birth_date date,
  created_at timestamptz DEFAULT now(),
  UNIQUE(clinic_id, whatsapp_number)
);

CREATE TABLE public.appointments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id uuid NOT NULL REFERENCES public.clinics(id) ON DELETE CASCADE,
  patient_id uuid NOT NULL REFERENCES public.patients(id) ON DELETE CASCADE,
  doctor_id uuid NOT NULL REFERENCES public.doctors(id) ON DELETE RESTRICT,
  scheduled_at timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'scheduled'
    CHECK (status IN ('scheduled', 'completed', 'cancelled')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE public.conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id uuid NOT NULL REFERENCES public.clinics(id) ON DELETE CASCADE,
  patient_id uuid REFERENCES public.patients(id) ON DELETE CASCADE,
  whatsapp_number text,
  messages jsonb DEFAULT '[]'::jsonb,
  state text DEFAULT 'MENU',
  updated_at timestamptz DEFAULT now(),
  UNIQUE(clinic_id, patient_id)
);

CREATE TABLE public.cancellation_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id uuid NOT NULL REFERENCES public.clinics(id) ON DELETE CASCADE,
  patient_id uuid NOT NULL REFERENCES public.patients(id) ON DELETE CASCADE,
  appointment_id uuid NOT NULL REFERENCES public.appointments(id) ON DELETE CASCADE,
  cancellation_reason_raw text,
  cancellation_category text,
  rescheduled boolean DEFAULT false,
  transferred_to_human boolean DEFAULT false,
  ai_summary text,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX idx_doctors_clinic ON public.doctors(clinic_id) WHERE active = true;

CREATE INDEX idx_patients_clinic_whatsapp ON public.patients(clinic_id, whatsapp_number);
CREATE INDEX idx_patients_clinic_cpf ON public.patients(clinic_id, cpf_last4);
CREATE INDEX idx_patients_clinic_birth ON public.patients(clinic_id, birth_date);

CREATE INDEX idx_appointments_clinic_patient ON public.appointments(clinic_id, patient_id);
CREATE INDEX idx_appointments_clinic_doctor_scheduled ON public.appointments(clinic_id, doctor_id, scheduled_at);

CREATE INDEX idx_appointments_future_scheduled ON public.appointments(patient_id, scheduled_at)
  WHERE status = 'scheduled';

CREATE INDEX idx_conversations_clinic_patient ON public.conversations(clinic_id, patient_id);

CREATE UNIQUE INDEX conversations_unidentified_unique
  ON public.conversations(clinic_id, whatsapp_number)
  WHERE patient_id IS NULL;

CREATE INDEX idx_conversations_clinic_whatsapp
  ON public.conversations(clinic_id, whatsapp_number);

-- Test Data Seed
INSERT INTO public.clinics (id, name, whatsapp_number, address, business_hours, accepted_insurances, bot_prompt, human_agent_number)
VALUES (
  '11111111-1111-1111-1111-111111111111',
  'Clínica Saúde Total (Teste)',
  '5511999999998',
  'Rua dos Testes, 123 - São Paulo/SP',
  '{"seg": "08:00-18:00", "ter": "08:00-18:00", "qua": "08:00-18:00", "qui": "08:00-18:00", "sex": "08:00-17:00"}'::jsonb,
  ARRAY['Unimed', 'Amil', 'SulAmérica', 'Particular'],
  'Você é a assistente virtual da Clínica Saúde Total. Seja educada, empática e objetiva. Responda sempre em português. Use o nome do paciente quando disponível. Nunca invente informações que não estejam no contexto fornecido.',
  '5511999999997'
);

INSERT INTO public.doctors (id, clinic_id, name, specialty, active, consultation_price)
VALUES
  ('aaaa1111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Dra. Maria Silva', 'Clínica Geral', true, 180.00),
  ('aaaa2222-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Dr. João Santos', 'Cardiologia', true, 350.00),
  ('aaaa3333-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Dra. Ana Costa', 'Dermatologia', true, 280.00);

INSERT INTO public.patients (id, clinic_id, whatsapp_number, name, insurance, cpf_last4, birth_date)
VALUES
  ('bbbb1111-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '11111111-1111-1111-1111-111111111111', '5511999999999', 'Carlos Oliveira', 'Unimed', '1234', '1985-03-15');

INSERT INTO public.appointments (id, clinic_id, patient_id, doctor_id, scheduled_at, status)
VALUES
  ('cccc1111-cccc-cccc-cccc-cccccccccccc', '11111111-1111-1111-1111-111111111111', 'bbbb1111-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'aaaa1111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', now() + interval '7 days', 'scheduled');

INSERT INTO public.conversations (clinic_id, patient_id, messages, state)
VALUES
  ('11111111-1111-1111-1111-111111111111', 'bbbb1111-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '[]'::jsonb, 'MENU');

-- Enable Row Level Security (RLS)
ALTER TABLE public.clinics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.doctors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.patients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cancellation_logs ENABLE ROW LEVEL SECURITY;
