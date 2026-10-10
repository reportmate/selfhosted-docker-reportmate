-- ReportMate self-host base schema.
--
-- The schema has two owners, and this file is only one of them.
--
--   This file   creates the tables the API writes to but does not create:
--               devices, events, and one table per collection module.
--   The API     owns everything else through the Alembic migrations it runs at
--               startup (alembic/versions in reportmate/reportmate-api): its
--               own tables (usage_history, api_keys, app_settings,
--               ingest_failures, device_ingest_state and others), the
--               dashboard counter columns on installs, and the performance
--               indexes, including the device_id indexes on the module tables.
--
-- Keep anything those migrations create out of this file, so each object has
-- one definition. CI starts the published API image on this schema and sends a
-- check-in carrying every module, which fails when the two drift apart.
--
-- Every statement is idempotent. Postgres runs this file once, on an empty
-- volume; to bring an existing database up to date, run it again (see
-- "Upgrading an existing database" in the README).

SET client_min_messages = warning;

-- =============================================================================
-- DEVICES
-- =============================================================================

-- id and serial_number both hold the hardware serial number; device_id holds
-- the hardware UUID.
CREATE TABLE IF NOT EXISTS devices (
    id VARCHAR(255) PRIMARY KEY,
    device_id VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(500),
    serial_number VARCHAR(100) UNIQUE NOT NULL,
    hostname VARCHAR(255),
    model VARCHAR(500),
    manufacturer VARCHAR(500),
    os VARCHAR(255),
    os_name VARCHAR(100),
    os_version VARCHAR(100),
    processor VARCHAR(500),
    memory VARCHAR(100),
    storage VARCHAR(100),
    graphics VARCHAR(500),
    architecture VARCHAR(50),
    last_seen TIMESTAMP WITH TIME ZONE,
    status VARCHAR(50) DEFAULT 'online',
    ip_address_v4 VARCHAR(45),
    ip_address_v6 VARCHAR(45),
    mac_address_primary VARCHAR(17),
    uptime VARCHAR(100),
    client_version VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT unique_serial_device_pair UNIQUE (serial_number, device_id)
);

-- Columns added after the table first shipped. ADD COLUMN IF NOT EXISTS brings
-- an older database up to date when this file is run again.
ALTER TABLE devices ADD COLUMN IF NOT EXISTS client_version VARCHAR(50);
ALTER TABLE devices ADD COLUMN IF NOT EXISTS platform VARCHAR(50);
ALTER TABLE devices ADD COLUMN IF NOT EXISTS archived BOOLEAN DEFAULT FALSE;
ALTER TABLE devices ADD COLUMN IF NOT EXISTS archived_at TIMESTAMPTZ;

UPDATE devices SET archived = FALSE WHERE archived IS NULL;
ALTER TABLE devices ALTER COLUMN archived SET NOT NULL;

COMMENT ON COLUMN devices.platform IS 'Operating system platform (Windows, macOS) reported by the client';
COMMENT ON COLUMN devices.archived IS 'Soft deletion flag - when TRUE, device is hidden from default views but data remains in database';
COMMENT ON COLUMN devices.archived_at IS 'Timestamp when device was archived';

CREATE INDEX IF NOT EXISTS idx_devices_last_seen ON devices(last_seen);
CREATE INDEX IF NOT EXISTS idx_devices_status ON devices(status);
CREATE INDEX IF NOT EXISTS idx_devices_platform ON devices(platform);
CREATE INDEX IF NOT EXISTS idx_devices_archived_status ON devices(archived, status);

-- =============================================================================
-- EVENTS
-- =============================================================================

CREATE TABLE IF NOT EXISTS events (
    id SERIAL PRIMARY KEY,
    device_id VARCHAR(255) NOT NULL,
    event_type VARCHAR(20) NOT NULL CHECK (event_type IN ('success', 'warning', 'error', 'info', 'system')),
    module_id VARCHAR(50),
    message TEXT,
    details JSONB,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE
);

ALTER TABLE events ADD COLUMN IF NOT EXISTS module_id VARCHAR(50);

-- The (device_id, module_id) index belongs to the API's migrations, which
-- replaced the original unique index with a plain one. Creating either here
-- would undo that.
CREATE INDEX IF NOT EXISTS idx_events_event_type ON events(event_type);
CREATE INDEX IF NOT EXISTS idx_events_timestamp ON events(timestamp);

-- =============================================================================
-- MODULE TABLES
-- =============================================================================

-- One row per device per module; data holds the module's JSON as the client
-- sent it, and the unique constraint indexes device_id. Every name in
-- _MODULE_TABLES (routers/admin.py in reportmate-api) needs a table: ingest
-- writes to the live modules, and device deletion and orphan cleanup touch all
-- of them, including displays, printers and profiles, which current clients
-- report inside peripherals and management.

CREATE TABLE IF NOT EXISTS applications (
    id SERIAL PRIMARY KEY,
    device_id VARCHAR(255) NOT NULL,
    data JSONB NOT NULL,
    collected_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE,
    CONSTRAINT unique_applications_per_device UNIQUE(device_id)
);

CREATE TABLE IF NOT EXISTS displays (
    id SERIAL PRIMARY KEY,
    device_id VARCHAR(255) NOT NULL,
    data JSONB NOT NULL,
    collected_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE,
    CONSTRAINT unique_displays_per_device UNIQUE(device_id)
);

CREATE TABLE IF NOT EXISTS hardware (
    id SERIAL PRIMARY KEY,
    device_id VARCHAR(255) NOT NULL,
    data JSONB NOT NULL,
    collected_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE,
    CONSTRAINT unique_hardware_per_device UNIQUE(device_id)
);

CREATE TABLE IF NOT EXISTS identity (
    id SERIAL PRIMARY KEY,
    device_id VARCHAR(255) NOT NULL,
    data JSONB NOT NULL,
    collected_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE,
    CONSTRAINT unique_identity_per_device UNIQUE(device_id)
);

CREATE TABLE IF NOT EXISTS installs (
    id SERIAL PRIMARY KEY,
    device_id VARCHAR(255) NOT NULL,
    data JSONB NOT NULL,
    collected_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE,
    CONSTRAINT unique_installs_per_device UNIQUE(device_id)
);

CREATE TABLE IF NOT EXISTS inventory (
    id SERIAL PRIMARY KEY,
    device_id VARCHAR(255) NOT NULL,
    data JSONB NOT NULL,
    collected_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE,
    CONSTRAINT unique_inventory_per_device UNIQUE(device_id)
);

CREATE TABLE IF NOT EXISTS management (
    id SERIAL PRIMARY KEY,
    device_id VARCHAR(255) NOT NULL,
    data JSONB NOT NULL,
    collected_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE,
    CONSTRAINT unique_management_per_device UNIQUE(device_id)
);

CREATE TABLE IF NOT EXISTS network (
    id SERIAL PRIMARY KEY,
    device_id VARCHAR(255) NOT NULL,
    data JSONB NOT NULL,
    collected_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE,
    CONSTRAINT unique_network_per_device UNIQUE(device_id)
);

CREATE TABLE IF NOT EXISTS peripherals (
    id SERIAL PRIMARY KEY,
    device_id VARCHAR(255) NOT NULL,
    data JSONB NOT NULL,
    collected_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE,
    CONSTRAINT unique_peripherals_per_device UNIQUE(device_id)
);

CREATE TABLE IF NOT EXISTS printers (
    id SERIAL PRIMARY KEY,
    device_id VARCHAR(255) NOT NULL,
    data JSONB NOT NULL,
    collected_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE,
    CONSTRAINT unique_printers_per_device UNIQUE(device_id)
);

CREATE TABLE IF NOT EXISTS profiles (
    id SERIAL PRIMARY KEY,
    device_id VARCHAR(255) NOT NULL,
    data JSONB NOT NULL,
    collected_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE,
    CONSTRAINT unique_profiles_per_device UNIQUE(device_id)
);

CREATE TABLE IF NOT EXISTS security (
    id SERIAL PRIMARY KEY,
    device_id VARCHAR(255) NOT NULL,
    data JSONB NOT NULL,
    collected_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE,
    CONSTRAINT unique_security_per_device UNIQUE(device_id)
);

CREATE TABLE IF NOT EXISTS system (
    id SERIAL PRIMARY KEY,
    device_id VARCHAR(255) NOT NULL,
    data JSONB NOT NULL,
    collected_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE,
    CONSTRAINT unique_system_per_device UNIQUE(device_id)
);

-- =============================================================================
-- updated_at TRIGGERS
-- =============================================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- CREATE OR REPLACE TRIGGER needs PostgreSQL 14 or later.
CREATE OR REPLACE TRIGGER update_devices_updated_at BEFORE UPDATE ON devices FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE OR REPLACE TRIGGER update_applications_updated_at BEFORE UPDATE ON applications FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE OR REPLACE TRIGGER update_displays_updated_at BEFORE UPDATE ON displays FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE OR REPLACE TRIGGER update_hardware_updated_at BEFORE UPDATE ON hardware FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE OR REPLACE TRIGGER update_identity_updated_at BEFORE UPDATE ON identity FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE OR REPLACE TRIGGER update_installs_updated_at BEFORE UPDATE ON installs FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE OR REPLACE TRIGGER update_inventory_updated_at BEFORE UPDATE ON inventory FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE OR REPLACE TRIGGER update_management_updated_at BEFORE UPDATE ON management FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE OR REPLACE TRIGGER update_network_updated_at BEFORE UPDATE ON network FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE OR REPLACE TRIGGER update_peripherals_updated_at BEFORE UPDATE ON peripherals FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE OR REPLACE TRIGGER update_printers_updated_at BEFORE UPDATE ON printers FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE OR REPLACE TRIGGER update_profiles_updated_at BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE OR REPLACE TRIGGER update_security_updated_at BEFORE UPDATE ON security FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE OR REPLACE TRIGGER update_system_updated_at BEFORE UPDATE ON system FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
