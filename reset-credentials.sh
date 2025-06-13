#!/bin/bash

# Reset credentials and setup multi-agent system
echo "Resetting credentials and setting up multi-agent system..."

# First, run database migration to ensure new schema is in place
echo "Running database migration..."
npm run db:push

# Create SQL script to reset agents and setup proper credentials
cat > temp_reset.sql << 'EOF'
-- Clear existing agents
DELETE FROM agents;

-- Insert admin agent with proper password hash
INSERT INTO agents (
    email, 
    password, 
    name, 
    role, 
    is_active, 
    is_available,
    department,
    phone,
    created_at,
    updated_at
) VALUES (
    'admin@helpboard.com',
    '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', -- password: admin123
    'Admin User',
    'admin',
    true,
    true,
    'Administration',
    '+1-555-0001',
    NOW(),
    NOW()
);

-- Insert regular agent
INSERT INTO agents (
    email, 
    password, 
    name, 
    role, 
    is_active, 
    is_available,
    department,
    phone,
    created_at,
    updated_at
) VALUES (
    'agent@helpboard.com',
    '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', -- password: password123
    'Support Agent',
    'agent',
    true,
    true,
    'Customer Support',
    '+1-555-0002',
    NOW(),
    NOW()
);

-- Insert supervisor agent
INSERT INTO agents (
    email, 
    password, 
    name, 
    role, 
    is_active, 
    is_available,
    department,
    phone,
    created_at,
    updated_at
) VALUES (
    'supervisor@helpboard.com',
    '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', -- password: supervisor123
    'Support Supervisor',
    'supervisor',
    true,
    true,
    'Customer Support',
    '+1-555-0003',
    NOW(),
    NOW()
);
EOF

# Execute the SQL script using Docker if database is running in Docker
if docker compose -f docker-compose.dev.yml ps | grep -q "db.*Up"; then
    echo "Executing SQL script via Docker..."
    docker compose -f docker-compose.dev.yml exec -T db psql -U helpboard_user -d helpboard < temp_reset.sql
else
    echo "Database container not running. Please start it first with:"
    echo "docker compose -f docker-compose.dev.yml up -d db"
    exit 1
fi

# Clean up temp file
rm temp_reset.sql

echo "Credentials reset complete!"
echo ""
echo "Available login credentials:"
echo "Admin: admin@helpboard.com / admin123"
echo "Agent: agent@helpboard.com / password123"  
echo "Supervisor: supervisor@helpboard.com / supervisor123"
echo ""
echo "You can now login to your application at helpboard.selfany.com"