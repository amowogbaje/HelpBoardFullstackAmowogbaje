#!/bin/bash

# Deployment utility functions for HelpBoard

# Debug and troubleshooting functions
debug_application() {
    local compose_file="docker-compose.dev.yml"
    
    echo "=== HelpBoard Debug Information ==="
    echo "Timestamp: $(date)"
    echo ""
    
    echo "=== Service Status ==="
    docker compose -f "$compose_file" ps
    echo ""
    
    echo "=== Recent Application Logs ==="
    docker compose -f "$compose_file" logs --tail=20 app
    echo ""
    
    echo "=== Database Status ==="
    if docker compose -f "$compose_file" exec -T db pg_isready -U helpboard_user -d helpboard; then
        echo "Database is accessible"
        echo "Tables:"
        docker compose -f "$compose_file" exec -T db psql -U helpboard_user -d helpboard -c "\dt"
        echo ""
        echo "Agent count:"
        docker compose -f "$compose_file" exec -T db psql -U helpboard_user -d helpboard -c "SELECT COUNT(*) FROM agents;"
    else
        echo "Database is not accessible"
    fi
    echo ""
    
    echo "=== Health Check ==="
    curl -s "https://helpboard.selfany.com/api/health" || echo "Health endpoint not responding"
    echo ""
    
    echo "=== Network Connectivity ==="
    docker compose -f "$compose_file" exec -T app curl -s localhost:3000/api/health || echo "Internal health check failed"
}

# Quick fix for common issues
quick_fix() {
    local compose_file="docker-compose.dev.yml"
    
    echo "Applying quick fixes..."
    
    # Restart services
    echo "Restarting services..."
    docker compose -f "$compose_file" restart
    
    # Wait for database
    echo "Waiting for database..."
    sleep 15
    
    # Re-run schema migration
    echo "Re-running database schema..."
    docker compose -f "$compose_file" exec -T app npm run db:push
    
    # Check health
    sleep 10
    curl -s "https://helpboard.selfany.com/api/health" && echo "✓ Application is responding"
}

# Test login functionality
test_login() {
    local compose_file="docker-compose.dev.yml"
    
    echo "=== Testing Login Functionality ==="
    
    # Test admin login
    echo "Testing admin login..."
    curl -v -X POST "https://helpboard.selfany.com/api/auth/login" \
        -H "Content-Type: application/json" \
        -d '{"email":"admin@helpboard.com","password":"admin123"}' 2>&1
    
    echo ""
    echo ""
    
    # Check database agents
    echo "Checking database agents..."
    docker compose -f "$compose_file" exec -T db psql -U helpboard_user -d helpboard -c "SELECT email, name, role FROM agents;"
}

# Clean deployment (removes containers and volumes)
clean_deploy() {
    local compose_file="docker-compose.dev.yml"
    
    echo "Performing clean deployment..."
    
    # Stop and remove everything
    docker compose -f "$compose_file" down -v
    
    # Remove images
    docker compose -f "$compose_file" down --rmi all
    
    # Clean Docker system
    docker system prune -f
    
    echo "Clean deployment completed. Run ./deploy-dev.sh to redeploy."
}

# Show usage
show_usage() {
    echo "HelpBoard Deployment Utilities"
    echo ""
    echo "Usage: ./deployment-helpers.sh [command]"
    echo ""
    echo "Commands:"
    echo "  debug     - Show comprehensive debug information"
    echo "  quick-fix - Apply quick fixes for common issues"
    echo "  test-login - Test login functionality"
    echo "  clean     - Clean deployment (removes all containers/volumes)"
    echo "  help      - Show this help message"
}

# Main function
main() {
    case "${1:-help}" in
        debug)
            debug_application
            ;;
        quick-fix)
            quick_fix
            ;;
        test-login)
            test_login
            ;;
        clean)
            clean_deploy
            ;;
        help|*)
            show_usage
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi