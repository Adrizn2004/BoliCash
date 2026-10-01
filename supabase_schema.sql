-- =========================================================
-- BoliCash - Estructura base para Supabase
-- =========================================================

CREATE TABLE IF NOT EXISTS usuarios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    pin TEXT NOT NULL,
    estado_activo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre TEXT NOT NULL UNIQUE,
    descripcion TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS usuario_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    rol_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (usuario_id, rol_id)
);

CREATE TABLE IF NOT EXISTS bitacora_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID REFERENCES usuarios(id) ON DELETE SET NULL,
    accion TEXT NOT NULL,
    modulo TEXT NOT NULL,
    detalle JSONB,
    ip_origen TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =========================================================
-- Roles base del sistema
-- =========================================================
INSERT INTO roles (nombre, descripcion)
VALUES
    ('Administrador del Sistema TI', 'Control total del sistema y seguridad.'),
    ('Administrador Comercial', 'Gestión comercial y operativa del negocio.'),
    ('Supervisor', 'Supervisión de equipos y control de indicadores.'),
    ('Asesor Comercial B2B', 'Atención y cierre de clientes B2B.'),
    ('Reporting', 'Consulta y análisis de reportes KPI.')
ON CONFLICT (nombre) DO NOTHING;

-- =========================================================
-- Usuario inicial con todos los roles
-- =========================================================
INSERT INTO usuarios (nombre, email, pin, estado_activo)
VALUES ('belen montes', 'belen.montes@gmail.com', '123456', TRUE)
ON CONFLICT (email) DO NOTHING;

WITH usuario AS (
    SELECT id
    FROM usuarios
    WHERE email = 'belen.montes@gmail.com'
),
roles_ids AS (
    SELECT id
    FROM roles
    WHERE nombre IN (
        'Administrador del Sistema TI',
        'Administrador Comercial',
        'Supervisor',
        'Asesor Comercial B2B',
        'Reporting'
    )
)
INSERT INTO usuario_roles (usuario_id, rol_id)
SELECT u.id, r.id
FROM usuario u
CROSS JOIN roles_ids r
ON CONFLICT (usuario_id, rol_id) DO NOTHING;

-- =========================================================
-- Auditoría inicial
-- =========================================================
INSERT INTO bitacora_logs (usuario_id, accion, modulo, detalle)
SELECT u.id, 'inicializacion', 'seguridad', '{"mensaje": "Usuario inicial con todos los roles asignados"}'::jsonb
FROM usuarios u
WHERE u.email = 'belen.montes@gmail.com'
ON CONFLICT DO NOTHING;
