-- Production-only database initialization
-- Create additional databases for solid_queue, solid_cache, solid_cable
CREATE DATABASE conduit_app_production_cache OWNER conduit_app;
CREATE DATABASE conduit_app_production_queue OWNER conduit_app;
CREATE DATABASE conduit_app_production_cable OWNER conduit_app;

-- Grant necessary permissions
GRANT ALL PRIVILEGES ON DATABASE conduit_app_production_cache TO conduit_app;
GRANT ALL PRIVILEGES ON DATABASE conduit_app_production_queue TO conduit_app;
GRANT ALL PRIVILEGES ON DATABASE conduit_app_production_cable TO conduit_app;
