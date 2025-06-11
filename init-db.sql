-- Initialize HelpBoard database with proper permissions and settings

-- Create database if it doesn't exist
SELECT 'CREATE DATABASE helpboard'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'helpboard');

-- Connect to helpboard database
\c helpboard;

-- Create extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Set timezone
SET timezone = 'UTC';

-- Grant permissions to helpboard_user
GRANT ALL PRIVILEGES ON DATABASE helpboard TO helpboard_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO helpboard_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO helpboard_user;

-- Set default privileges for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO helpboard_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO helpboard_user;