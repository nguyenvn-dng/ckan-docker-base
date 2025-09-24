#!/bin/bash

# CKAN Performance Optimization Script

echo "=== CKAN Performance Monitoring ==="

# Function to test CKAN response time
test_ckan_performance() {
    echo "Testing CKAN response times..."
    
    # Test homepage
    echo -n "Homepage: "
    curl -o /dev/null -s -w "%{time_total}s\n" http://localhost:5000/
    
    # Test API status
    echo -n "API Status: " 
    curl -o /dev/null -s -w "%{time_total}s\n" http://localhost:5000/api/3/action/status_show
    
    # Test dataset list
    echo -n "Dataset List: "
    curl -o /dev/null -s -w "%{time_total}s\n" http://localhost:5000/dataset/
}

# Function to check container resources
check_resources() {
    echo "=== Container Resource Usage ==="
    docker stats ckan_app --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
}

# Function to check uWSGI stats  
check_uwsgi() {
    echo "=== uWSGI Process Info ==="
    docker exec ckan_app ps aux | grep uwsgi
}

# Function to show optimization tips
show_tips() {
    echo "=== Performance Optimization Tips ==="
    echo "1. Enable Redis caching for better performance"
    echo "2. Use external PostgreSQL with connection pooling"
    echo "3. Configure Solr with proper heap size"
    echo "4. Use nginx reverse proxy for static files"
    echo "5. Enable gzip compression"
    echo "6. Optimize database queries with indexes"
    echo ""
    echo "=== Current Configuration ==="
    echo "Workers: $(docker exec ckan_app printenv UWSGI_WORKERS || echo '4')"
    echo "Buffer Size: $(docker exec ckan_app printenv UWSGI_BUFFER_SIZE || echo '32768')"
    echo "Max Requests: $(docker exec ckan_app printenv UWSGI_MAX_REQUESTS || echo '1000')"
    echo "Harakiri: $(docker exec ckan_app printenv UWSGI_HARAKIRI || echo '300')"
}

# Main execution
case "$1" in
    "test")
        test_ckan_performance
        ;;
    "resources") 
        check_resources
        ;;
    "uwsgi")
        check_uwsgi
        ;;
    "tips")
        show_tips
        ;;
    "all"|"")
        test_ckan_performance
        echo ""
        check_resources
        echo ""
        check_uwsgi
        echo ""
        show_tips
        ;;
    *)
        echo "Usage: $0 {test|resources|uwsgi|tips|all}"
        echo "  test      - Test CKAN response times"
        echo "  resources - Show container resource usage" 
        echo "  uwsgi     - Show uWSGI process info"
        echo "  tips      - Show optimization tips"
        echo "  all       - Run all checks (default)"
        ;;
esac