-- GH Consulting Dashboard Schema
-- Run this in Supabase SQL Editor

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Clients table
CREATE TABLE IF NOT EXISTS clients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email TEXT UNIQUE NOT NULL,
    nombre TEXT NOT NULL,
    negocio TEXT,
    nicho TEXT,
    plataformas TEXT,
    ingresos_actuales INTEGER DEFAULT 0,
    clientes_actuales INTEGER DEFAULT 0,
    objetivo INTEGER DEFAULT 0,
    problema_principal TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Weekly reports table
CREATE TABLE IF NOT EXISTS weekly_reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id UUID REFERENCES clients(id) ON DELETE CASCADE,
    ingresos INTEGER DEFAULT 0,
    clientes INTEGER DEFAULT 0,
    calls INTEGER DEFAULT 0,
    leads INTEGER DEFAULT 0,
    contenido INTEGER DEFAULT 0,
    seguidores INTEGER DEFAULT 0,
    notas TEXT,
    week_number INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Calls/sessions table
CREATE TABLE IF NOT EXISTS calls (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id UUID REFERENCES clients(id) ON DELETE CASCADE,
    fecha DATE NOT NULL,
    duracion INTEGER DEFAULT 30,
    transcript TEXT,
    problemas TEXT,
    sugerencias TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Problems/blockers table
CREATE TABLE IF NOT EXISTS problems (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id UUID REFERENCES clients(id) ON DELETE CASCADE,
    titulo TEXT NOT NULL,
    descripcion TEXT,
    status TEXT DEFAULT 'open' CHECK (status IN ('open', 'resolved')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    resolved_at TIMESTAMPTZ
);

-- Client links table
CREATE TABLE IF NOT EXISTS client_links (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id UUID REFERENCES clients(id) ON DELETE CASCADE,
    drive TEXT,
    miro TEXT,
    otros TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(client_id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_weekly_reports_client ON weekly_reports(client_id);
CREATE INDEX IF NOT EXISTS idx_weekly_reports_created ON weekly_reports(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_calls_client ON calls(client_id);
CREATE INDEX IF NOT EXISTS idx_calls_fecha ON calls(fecha DESC);
CREATE INDEX IF NOT EXISTS idx_problems_client ON problems(client_id);
CREATE INDEX IF NOT EXISTS idx_problems_status ON problems(status);

-- Row Level Security (RLS)
ALTER TABLE clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE weekly_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE calls ENABLE ROW LEVEL SECURITY;
ALTER TABLE problems ENABLE ROW LEVEL SECURITY;
ALTER TABLE client_links ENABLE ROW LEVEL SECURITY;

-- Policies: Clients can only see their own data
CREATE POLICY "Clients can view own data" ON clients
    FOR SELECT USING (auth.email() = email);

CREATE POLICY "Clients can update own data" ON clients
    FOR UPDATE USING (auth.email() = email);

CREATE POLICY "Anyone can insert clients" ON clients
    FOR INSERT WITH CHECK (true);

-- Weekly reports policies
CREATE POLICY "Clients can view own reports" ON weekly_reports
    FOR SELECT USING (client_id IN (SELECT id FROM clients WHERE email = auth.email()));

CREATE POLICY "Clients can insert own reports" ON weekly_reports
    FOR INSERT WITH CHECK (client_id IN (SELECT id FROM clients WHERE email = auth.email()));

-- Calls policies
CREATE POLICY "Clients can view own calls" ON calls
    FOR SELECT USING (client_id IN (SELECT id FROM clients WHERE email = auth.email()));

CREATE POLICY "Clients can insert own calls" ON calls
    FOR INSERT WITH CHECK (client_id IN (SELECT id FROM clients WHERE email = auth.email()));

CREATE POLICY "Clients can delete own calls" ON calls
    FOR DELETE USING (client_id IN (SELECT id FROM clients WHERE email = auth.email()));

-- Problems policies
CREATE POLICY "Clients can view own problems" ON problems
    FOR SELECT USING (client_id IN (SELECT id FROM clients WHERE email = auth.email()));

CREATE POLICY "Clients can manage own problems" ON problems
    FOR ALL USING (client_id IN (SELECT id FROM clients WHERE email = auth.email()));

-- Client links policies
CREATE POLICY "Clients can view own links" ON client_links
    FOR SELECT USING (client_id IN (SELECT id FROM clients WHERE email = auth.email()));

CREATE POLICY "Clients can manage own links" ON client_links
    FOR ALL USING (client_id IN (SELECT id FROM clients WHERE email = auth.email()));

-- Admin policies (for Guillermo)
-- You'll need to set your email as admin in Supabase Auth

-- Function to auto-calculate week number
CREATE OR REPLACE FUNCTION calculate_week_number()
RETURNS TRIGGER AS $$
BEGIN
    NEW.week_number := (
        SELECT COALESCE(MAX(week_number), 0) + 1 
        FROM weekly_reports 
        WHERE client_id = NEW.client_id
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_week_number
    BEFORE INSERT ON weekly_reports
    FOR EACH ROW
    EXECUTE FUNCTION calculate_week_number();

-- Function to update timestamps
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_clients_updated_at
    BEFORE UPDATE ON clients
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_links_updated_at
    BEFORE UPDATE ON client_links
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();
