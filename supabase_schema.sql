-- ============================================
-- MS MEDICIONES — SCHEMA COMPLETO SUPABASE
-- Proyecto: ms-mediciones
-- ============================================

-- 1. TABLA DE PERFILES DE USUARIO (extiende auth.users)
CREATE TABLE public.perfiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  nombre TEXT NOT NULL,
  iniciales TEXT NOT NULL,
  rol TEXT NOT NULL CHECK (rol IN ('admin', 'medidor')),
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. OBRAS
CREATE TABLE public.obras (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  nombre TEXT NOT NULL,
  descripcion TEXT,
  ciudad TEXT,
  status TEXT DEFAULT 'activa' CHECK (status IN ('activa', 'pausada', 'finalizada')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. AREAS POR OBRA
CREATE TABLE public.areas (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  obra_id UUID REFERENCES public.obras(id) ON DELETE CASCADE NOT NULL,
  nombre TEXT NOT NULL,
  disciplina TEXT NOT NULL CHECK (disciplina IN ('obra', 'carpinteria')),
  orden INT DEFAULT 0
);

-- 4. ASIGNACION USUARIOS → OBRAS
CREATE TABLE public.usuario_obras (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  usuario_id UUID REFERENCES public.perfiles(id) ON DELETE CASCADE NOT NULL,
  obra_id UUID REFERENCES public.obras(id) ON DELETE CASCADE NOT NULL,
  disciplina TEXT CHECK (disciplina IN ('obra', 'carpinteria', 'ambas')),
  UNIQUE(usuario_id, obra_id)
);

-- 5. PARTIDAS
CREATE TABLE public.partidas (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  obra_id UUID REFERENCES public.obras(id) ON DELETE CASCADE NOT NULL,
  codigo TEXT NOT NULL,
  nombre TEXT NOT NULL,
  area TEXT NOT NULL,
  disciplina TEXT NOT NULL CHECK (disciplina IN ('obra', 'carpinteria')),
  unidad TEXT NOT NULL,
  cantidad_presupuestada NUMERIC(12,4),
  nueva BOOLEAN DEFAULT false,
  orden INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. MEDICIONES
CREATE TABLE public.mediciones (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  partida_id UUID REFERENCES public.partidas(id) ON DELETE CASCADE NOT NULL,
  usuario_id UUID REFERENCES public.perfiles(id) NOT NULL,
  fecha DATE DEFAULT CURRENT_DATE,
  observaciones TEXT,
  total NUMERIC(12,4) DEFAULT 0,
  -- STATUS CARPINTERIA
  status_armado BOOLEAN DEFAULT false,
  status_embalaje BOOLEAN DEFAULT false,
  status_instalacion BOOLEAN DEFAULT false,
  status_ajuste BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. DIMENSIONES (filas de la planilla)
CREATE TABLE public.dimensiones (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  medicion_id UUID REFERENCES public.mediciones(id) ON DELETE CASCADE NOT NULL,
  descripcion TEXT,
  elementos_iguales NUMERIC(8,2) DEFAULT 1,
  ancho NUMERIC(10,4),
  alto NUMERIC(10,4),
  largo NUMERIC(10,4),
  neg_ancho NUMERIC(10,4),
  neg_alto NUMERIC(10,4),
  total NUMERIC(12,4),
  orden INT DEFAULT 0
);

-- 8. FOTOS
CREATE TABLE public.fotos (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  medicion_id UUID REFERENCES public.mediciones(id) ON DELETE CASCADE NOT NULL,
  url TEXT NOT NULL,
  nombre TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================

ALTER TABLE public.perfiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.obras ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.areas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usuario_obras ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.partidas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mediciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dimensiones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fotos ENABLE ROW LEVEL SECURITY;

-- Perfiles: cada uno ve el suyo; admin ve todos
CREATE POLICY "perfil_propio" ON public.perfiles
  FOR SELECT USING (auth.uid() = id OR EXISTS (
    SELECT 1 FROM public.perfiles p WHERE p.id = auth.uid() AND p.rol = 'admin'
  ));

CREATE POLICY "perfil_update_propio" ON public.perfiles
  FOR UPDATE USING (auth.uid() = id);

-- Obras: usuario ve solo las que tiene asignadas (admin ve todas)
CREATE POLICY "obras_asignadas" ON public.obras
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND rol = 'admin')
    OR
    EXISTS (SELECT 1 FROM public.usuario_obras WHERE usuario_id = auth.uid() AND obra_id = obras.id)
  );

CREATE POLICY "obras_admin_insert" ON public.obras
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND rol = 'admin')
  );

CREATE POLICY "obras_admin_update" ON public.obras
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND rol = 'admin')
  );

-- Areas
CREATE POLICY "areas_select" ON public.areas
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND rol = 'admin')
    OR
    EXISTS (SELECT 1 FROM public.usuario_obras WHERE usuario_id = auth.uid() AND obra_id = areas.obra_id)
  );

CREATE POLICY "areas_admin_write" ON public.areas
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND rol = 'admin')
  );

-- Usuario_obras
CREATE POLICY "uo_select" ON public.usuario_obras
  FOR SELECT USING (
    usuario_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND rol = 'admin')
  );

CREATE POLICY "uo_admin_write" ON public.usuario_obras
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND rol = 'admin')
  );

-- Partidas
CREATE POLICY "partidas_select" ON public.partidas
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND rol = 'admin')
    OR
    EXISTS (SELECT 1 FROM public.usuario_obras WHERE usuario_id = auth.uid() AND obra_id = partidas.obra_id)
  );

CREATE POLICY "partidas_insert" ON public.partidas
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.usuario_obras WHERE usuario_id = auth.uid() AND obra_id = partidas.obra_id)
    OR EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND rol = 'admin')
  );

CREATE POLICY "partidas_admin_update" ON public.partidas
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND rol = 'admin')
  );

-- Mediciones
CREATE POLICY "mediciones_select" ON public.mediciones
  FOR SELECT USING (
    usuario_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND rol = 'admin')
  );

CREATE POLICY "mediciones_insert" ON public.mediciones
  FOR INSERT WITH CHECK (usuario_id = auth.uid());

CREATE POLICY "mediciones_update" ON public.mediciones
  FOR UPDATE USING (
    usuario_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND rol = 'admin')
  );

-- Dimensiones
CREATE POLICY "dims_select" ON public.dimensiones
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.mediciones m WHERE m.id = medicion_id AND (
      m.usuario_id = auth.uid()
      OR EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND rol = 'admin')
    ))
  );

CREATE POLICY "dims_write" ON public.dimensiones
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.mediciones m WHERE m.id = medicion_id AND m.usuario_id = auth.uid())
    OR EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND rol = 'admin')
  );

-- Fotos
CREATE POLICY "fotos_select" ON public.fotos
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.mediciones m WHERE m.id = medicion_id AND (
      m.usuario_id = auth.uid()
      OR EXISTS (SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND rol = 'admin')
    ))
  );

CREATE POLICY "fotos_insert" ON public.fotos
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.mediciones m WHERE m.id = medicion_id AND m.usuario_id = auth.uid())
  );

-- ============================================
-- DATOS INICIALES
-- ============================================

-- Obras
INSERT INTO public.obras (id, nombre, descripcion, ciudad, status) VALUES
  ('11111111-1111-1111-1111-111111111111', 'El Tejar', 'Residencia', 'Venezuela', 'activa'),
  ('22222222-2222-2222-2222-222222222222', 'Cafetal / Oficina AK', 'Oficina', 'Venezuela', 'activa');

-- Areas El Tejar — Obra civil
INSERT INTO public.areas (obra_id, nombre, disciplina, orden) VALUES
  ('11111111-1111-1111-1111-111111111111','General','obra',1),
  ('11111111-1111-1111-1111-111111111111','Hall Entrada','obra',2),
  ('11111111-1111-1111-1111-111111111111','Sala / Comedor / Sala TV','obra',3),
  ('11111111-1111-1111-1111-111111111111','Cocina','obra',4),
  ('11111111-1111-1111-1111-111111111111','Lobby 1','obra',5),
  ('11111111-1111-1111-1111-111111111111','Habitación Principal','obra',6),
  ('11111111-1111-1111-1111-111111111111','Baño Ppal','obra',7),
  ('11111111-1111-1111-1111-111111111111','Vestier Hab Ppal','obra',8),
  ('11111111-1111-1111-1111-111111111111','Habitación 1','obra',9),
  ('11111111-1111-1111-1111-111111111111','Habitación 2','obra',10),
  ('11111111-1111-1111-1111-111111111111','Habitación Huésped','obra',11),
  ('11111111-1111-1111-1111-111111111111','Baño Huésped','obra',12),
  ('11111111-1111-1111-1111-111111111111','Hab de Servicio','obra',13),
  ('11111111-1111-1111-1111-111111111111','Baño Hab Servicio','obra',14),
  ('11111111-1111-1111-1111-111111111111','Family Room','obra',15),
  ('11111111-1111-1111-1111-111111111111','Estudio de Hombre','obra',16),
  ('11111111-1111-1111-1111-111111111111','Área de Servicio','obra',17),
  ('11111111-1111-1111-1111-111111111111','Escalera Principal','obra',18),
  ('11111111-1111-1111-1111-111111111111','Parrillera Piscina','obra',19),
  ('11111111-1111-1111-1111-111111111111','Marquesina','obra',20),
  ('11111111-1111-1111-1111-111111111111','Áreas Exterior','obra',21),
  ('11111111-1111-1111-1111-111111111111','Jardín Interno','obra',22),
  ('11111111-1111-1111-1111-111111111111','Cuarto de Bomba','obra',23),
  ('11111111-1111-1111-1111-111111111111','Hall de Habitaciones','obra',24),
  ('11111111-1111-1111-1111-111111111111','Pasillo Hab','obra',25),
  ('11111111-1111-1111-1111-111111111111','Cuarto de Rack','obra',26),
  ('11111111-1111-1111-1111-111111111111','Cuarto de Ropa Sucia','obra',27),
  ('11111111-1111-1111-1111-111111111111','Despensa','obra',28),
  ('11111111-1111-1111-1111-111111111111','Vestier Hab 1','obra',29),
  ('11111111-1111-1111-1111-111111111111','Vestier Hab 2','obra',30),
  ('11111111-1111-1111-1111-111111111111','Baño Visita','obra',31);

-- Areas El Tejar — Carpintería
INSERT INTO public.areas (obra_id, nombre, disciplina, orden) VALUES
  ('11111111-1111-1111-1111-111111111111','General','carpinteria',1),
  ('11111111-1111-1111-1111-111111111111','Sala / Comedor','carpinteria',2),
  ('11111111-1111-1111-1111-111111111111','Cocina','carpinteria',3),
  ('11111111-1111-1111-1111-111111111111','Habitación Principal','carpinteria',4),
  ('11111111-1111-1111-1111-111111111111','Vestier Hab Ppal','carpinteria',5),
  ('11111111-1111-1111-1111-111111111111','Habitación 1','carpinteria',6),
  ('11111111-1111-1111-1111-111111111111','Habitación 2','carpinteria',7),
  ('11111111-1111-1111-1111-111111111111','Hab de Servicio','carpinteria',8),
  ('11111111-1111-1111-1111-111111111111','Estudio','carpinteria',9),
  ('11111111-1111-1111-1111-111111111111','Hall','carpinteria',10);

-- Areas Cafetal — Obra civil
INSERT INTO public.areas (obra_id, nombre, disciplina, orden) VALUES
  ('22222222-2222-2222-2222-222222222222','General','obra',1),
  ('22222222-2222-2222-2222-222222222222','Recepción','obra',2),
  ('22222222-2222-2222-2222-222222222222','Oficina','obra',3),
  ('22222222-2222-2222-2222-222222222222','Oficina 1','obra',4),
  ('22222222-2222-2222-2222-222222222222','Cafetal','obra',5),
  ('22222222-2222-2222-2222-222222222222','Oficina AK','obra',6),
  ('22222222-2222-2222-2222-222222222222','Sala 1','obra',7),
  ('22222222-2222-2222-2222-222222222222','Anexo','obra',8),
  ('22222222-2222-2222-2222-222222222222','Habitación Auxiliar','obra',9),
  ('22222222-2222-2222-2222-222222222222','Habitación Niñas','obra',10),
  ('22222222-2222-2222-2222-222222222222','Habitación Niño','obra',11),
  ('22222222-2222-2222-2222-222222222222','Habitación Principal','obra',12),
  ('22222222-2222-2222-2222-222222222222','Área de Servicio','obra',13),
  ('22222222-2222-2222-2222-222222222222','Cocina','obra',14),
  ('22222222-2222-2222-2222-222222222222','Lavandería','obra',15),
  ('22222222-2222-2222-2222-222222222222','Habitación 1','obra',16),
  ('22222222-2222-2222-2222-222222222222','Habitación 2','obra',17),
  ('22222222-2222-2222-2222-222222222222','Habitación 3','obra',18),
  ('22222222-2222-2222-2222-222222222222','Baño Hab 1','obra',19),
  ('22222222-2222-2222-2222-222222222222','Baño Hab 2','obra',20),
  ('22222222-2222-2222-2222-222222222222','Baño Hab 3','obra',21),
  ('22222222-2222-2222-2222-222222222222','Baño Ppal','obra',22),
  ('22222222-2222-2222-2222-222222222222','Vestier','obra',23),
  ('22222222-2222-2222-2222-222222222222','Gimnasio','obra',24),
  ('22222222-2222-2222-2222-222222222222','Estacionamiento','obra',25),
  ('22222222-2222-2222-2222-222222222222','Fachada Ppal','obra',26),
  ('22222222-2222-2222-2222-222222222222','Piscina','obra',27),
  ('22222222-2222-2222-2222-222222222222','Techo','obra',28),
  ('22222222-2222-2222-2222-222222222222','Parrillera','obra',29),
  ('22222222-2222-2222-2222-222222222222','Baño Hab Servicio','obra',30);

-- Areas Cafetal — Carpintería
INSERT INTO public.areas (obra_id, nombre, disciplina, orden) VALUES
  ('22222222-2222-2222-2222-222222222222','General','carpinteria',1),
  ('22222222-2222-2222-2222-222222222222','Recepción','carpinteria',2),
  ('22222222-2222-2222-2222-222222222222','Oficina 1','carpinteria',3),
  ('22222222-2222-2222-2222-222222222222','Cafetal','carpinteria',4),
  ('22222222-2222-2222-2222-222222222222','Sala','carpinteria',5),
  ('22222222-2222-2222-2222-222222222222','Habitación Principal','carpinteria',6),
  ('22222222-2222-2222-2222-222222222222','Vestier','carpinteria',7),
  ('22222222-2222-2222-2222-222222222222','Cocina','carpinteria',8);

-- ============================================
-- TRIGGER updated_at en mediciones
-- ============================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER mediciones_updated_at
  BEFORE UPDATE ON public.mediciones
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================
-- STORAGE BUCKET para fotos
-- ============================================
INSERT INTO storage.buckets (id, name, public) VALUES ('fotos-obra', 'fotos-obra', false);

CREATE POLICY "fotos_upload" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'fotos-obra' AND auth.role() = 'authenticated');

CREATE POLICY "fotos_select" ON storage.objects
  FOR SELECT USING (bucket_id = 'fotos-obra' AND auth.role() = 'authenticated');
