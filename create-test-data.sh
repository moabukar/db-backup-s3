#!/bin/bash
# Create realistic test data to verify backup quality

kubectl exec -it deployment/postgres-replica -- psql -U root -d langfuse << 'EOF'
-- Create tables similar to a real application
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS projects (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    user_id INTEGER REFERENCES users(id),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Insert test data
INSERT INTO users (email, name) VALUES 
    ('test1@example.com', 'Test User 1'),
    ('test2@example.com', 'Test User 2'),
    ('test3@example.com', 'Test User 3');

INSERT INTO projects (name, description, user_id) VALUES 
    ('Test Project A', 'A sample project for testing backups', 1),
    ('Test Project B', 'Another test project', 2),
    ('Test Project C', 'Final test project', 3);

-- Verify data
SELECT 'Users count:' as info, count(*) as value FROM users
UNION ALL
SELECT 'Projects count:' as info, count(*) as value FROM projects;

SELECT u.name, p.name as project_name 
FROM users u 
JOIN projects p ON u.id = p.user_id;
EOF