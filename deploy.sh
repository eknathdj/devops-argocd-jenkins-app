#!/bin/bash
# deploy.sh - Complete deployment automation script

set -e  # Exit on error
set -o pipefail  # Exit on pipe failure

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="product-service"
KUBECTL="kubectl"
ARGOCD="argocd"

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl."
        exit 1
    fi
    
    # Check argocd CLI
    if ! command -v argocd &> /dev/null; then
        log_warn "argocd CLI not found. ArgoCD operations will be skipped."
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster."
        exit 1
    fi
    
    log_info "Prerequisites check passed ✓"
}

# Prompt helper that is safe for non-interactive environments.
# Usage: ask_prompt VAR_NAME "Prompt message" [default]
ask_prompt() {
    local _var_name="$1"; shift
    local _prompt="$1"; shift
    local _default="$1"

    # If running non-interactive, allow override via PRESET_ANSWER or SKIP_PROMPTS
    if ! test -t 0; then
        if [ -n "$PRESET_ANSWER" ]; then
            printf -v "${_var_name}" '%s' "$PRESET_ANSWER"
            return 0
        fi
        if [ "${SKIP_PROMPTS}" = "true" ]; then
            if [ -n "$_default" ]; then
                printf -v "${_var_name}" '%s' "$_default"
                return 0
            fi
        fi
        log_error "Non-interactive shell: prompt '$_prompt' cannot be answered. Set PRESET_ANSWER or SKIP_PROMPTS=true to proceed."
        exit 1
    fi

    # Interactive read
    read -p "${_prompt}" _reply
    if [ -z "$_reply" ] && [ -n "$_default" ]; then
        _reply="$_default"
    fi
    printf -v "${_var_name}" '%s' "$_reply"
}

create_namespace() {
    log_info "Creating namespace: $NAMESPACE"
    
    if kubectl get namespace $NAMESPACE &> /dev/null; then
        log_warn "Namespace $NAMESPACE already exists"
    else
        kubectl apply -f k8s/product-service/00-namespace.yaml
        log_info "Namespace created ✓"
    fi
}

deploy_secrets() {
    log_info "Deploying secrets..."
    
    # Check if secrets file exists
    if [ ! -f "k8s/product-service/01-secrets.yaml" ]; then
        log_error "Secrets file not found!"
        exit 1
    fi
    
    # Warn about default secrets
    log_warn "Make sure you've updated secrets with real values!"
    ask_prompt answer "Have you updated the secrets? (yes/no): " "no"
    if [ "$answer" != "yes" ]; then
        log_error "Please update secrets before deploying"
        exit 1
    fi
    
    kubectl apply -f k8s/product-service/01-secrets.yaml
    log_info "Secrets deployed ✓"
}

deploy_database() {
    log_info "Deploying PostgreSQL database..."
    
    kubectl apply -f k8s/product-service/02-postgres-db.yaml
    
    log_info "Waiting for PostgreSQL to be ready..."
    kubectl wait --for=condition=ready pod -l app=postgres -n $NAMESPACE --timeout=300s
    
    log_info "Database deployed ✓"
}

initialize_database() {
    log_info "Initializing database schema..."
    
    kubectl apply -f k8s/product-service/03-db-init-job.yaml
    
    log_info "Waiting for migration job to complete..."
    kubectl wait --for=condition=complete job/db-migration-job -n $NAMESPACE --timeout=300s
    
    # Check job status
    if kubectl get job db-migration-job -n $NAMESPACE -o jsonpath='{.status.succeeded}' | grep -q "1"; then
        log_info "Database initialized ✓"
    else
        log_error "Database migration failed!"
        kubectl logs -n $NAMESPACE job/db-migration-job
        exit 1
    fi
}

deploy_application() {
    log_info "Deploying application..."
    
    # Check if image is set
    if grep -q "eknathdj/product-service" k8s/product-service/04-app-deployment.yaml; then
        log_warn "Default image detected. Please update the image in deployment.yaml"
        ask_prompt image_name "Image registry/name: " "eknathdj/product-service:v1.2.3"
        # Use sed with a predictable backup to avoid corrupting the original on failure
        sed -i.bak "s|eknathdj/product-service:latest|${image_name}|g" k8s/product-service/04-app-deployment.yaml
        if [ $? -ne 0 ]; then
            log_error "Failed to update image in k8s/product-service/04-app-deployment.yaml"
            exit 1
        fi
    fi
    
    kubectl apply -f k8s/product-service/04-app-deployment.yaml
    
    log_info "Waiting for application to be ready..."
    kubectl rollout status deployment/product-service -n $NAMESPACE --timeout=300s
    
    log_info "Application deployed ✓"
}

deploy_ingress() {
    log_info "Deploying ingress..."

    # Check if domain is set
    if grep -q "yourdomain.com" k8s/product-service/05-ingress.yaml; then
        log_warn "Default domain detected. Please update the domain in ingress.yaml"
        ask_prompt domain "Your domain: " "example.com"
        sed -i.bak "s|yourdomain.com|${domain}|g" k8s/product-service/05-ingress.yaml
        if [ $? -ne 0 ]; then
            log_error "Failed to update domain in k8s/product-service/05-ingress.yaml"
            exit 1
        fi
    fi

    kubectl apply -f k8s/product-service/05-ingress.yaml
    log_info "Ingress deployed ✓"
}

deploy_monitoring() {
    log_info "Deploying monitoring configuration..."
    
    if kubectl apply -f k8s/product-service/06-monitoring.yaml 2>&1 | grep -q "error"; then
        log_warn "Monitoring deployment failed. This is optional."
    else
        log_info "Monitoring deployed ✓"
    fi
}

deploy_network_policies() {
    log_info "Deploying network policies..."
    
    if [ -f "k8s/product-service/07-network-policies.yaml" ]; then
        kubectl apply -f k8s/product-service/07-network-policies.yaml
        log_info "Network policies deployed ✓"
    else
        log_warn "Network policies file not found. Skipping."
    fi
}

deploy_rbac() {
    log_info "Deploying RBAC configuration..."
    
    if [ -f "k8s/product-service/08-rbac.yaml" ]; then
        kubectl apply -f k8s/product-service/08-rbac.yaml
        log_info "RBAC deployed ✓"
    else
        log_warn "RBAC file not found. Skipping."
    fi
}

setup_argocd() {
    log_info "Setting up ArgoCD application..."
    
    if ! command -v argocd &> /dev/null; then
        log_warn "ArgoCD CLI not found. Skipping ArgoCD setup."
        return
    fi
    
    kubectl apply -f argocd/product-service-app.yaml
    
    log_info "Syncing ArgoCD application..."
    # Run argocd app sync and check exit status to avoid masking failures
    ${ARGOCD} app sync product-service --force
    rc=$?
    if [ $rc -ne 0 ]; then
        log_error "argocd app sync product-service failed with exit code $rc"
        exit 1
    fi

    ${ARGOCD} app wait product-service --health --timeout 300
    rc=$?
    if [ $rc -ne 0 ]; then
        log_error "argocd app wait product-service failed with exit code $rc"
        exit 1
    fi
    
    log_info "ArgoCD setup complete ✓"
}

verify_deployment() {
    log_info "Verifying deployment..."
    
    echo ""
    echo "=== Namespace Resources ==="
    kubectl get all -n $NAMESPACE
    
    echo ""
    echo "=== Pod Status ==="
    kubectl get pods -n $NAMESPACE
    
    echo ""
    echo "=== Service Endpoints ==="
    kubectl get endpoints -n $NAMESPACE
    
    echo ""
    echo "=== Recent Events ==="
    kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | tail -10
    
    # Health check
    log_info "Running health checks..."
    
    POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=product-service -o jsonpath='{.items[0].metadata.name}')
    
    if [ -n "$POD_NAME" ]; then
        log_info "Testing application health endpoint..."
        kubectl exec -n $NAMESPACE $POD_NAME -- wget -qO- http://localhost:8080/health/live || log_warn "Health check failed"
    fi
    
    log_info "Deployment verification complete ✓"
}

rollback() {
    log_warn "Rolling back deployment..."
    
    kubectl rollout undo deployment/product-service -n $NAMESPACE
    kubectl rollout status deployment/product-service -n $NAMESPACE
    
    log_info "Rollback complete ✓"
}

cleanup() {
    log_warn "Cleaning up all resources..."
    
    ask_prompt answer "Are you sure you want to delete everything? (yes/no): " "no"
    if [ "$answer" != "yes" ]; then
        log_info "Cleanup cancelled"
        return
    fi
    
    log_info "Deleting namespace: $NAMESPACE"
    kubectl delete namespace $NAMESPACE --wait=true
    
    log_info "Cleanup complete ✓"
}

# Main menu
show_menu() {
    echo ""
    echo "================================"
    echo "Product Service Deployment"
    echo "================================"
    echo "1. Full Deployment (All steps)"
    echo "2. Deploy Namespace"
    echo "3. Deploy Secrets"
    echo "4. Deploy Database"
    echo "5. Initialize Database"
    echo "6. Deploy Application"
    echo "7. Deploy Ingress"
    echo "8. Deploy Monitoring"
    echo "9. Setup ArgoCD"
    echo "10. Verify Deployment"
    echo "11. Rollback"
    echo "12. Cleanup (Delete All)"
    echo "0. Exit"
    echo "================================"
}

# Main execution
main() {
    check_prerequisites
    
    if [ $# -eq 0 ]; then
        # Interactive mode
        while true; do
            show_menu
            ask_prompt choice "Select an option: " "0"
            
            case $choice in
                1)
                    create_namespace
                    deploy_secrets
                    deploy_database
                    initialize_database
                    deploy_application
                    deploy_ingress
                    deploy_monitoring
                    deploy_network_policies
                    deploy_rbac
                    setup_argocd
                    verify_deployment
                    log_info "Full deployment complete! 🎉"
                    ;;
                2) create_namespace ;;
                3) deploy_secrets ;;
                4) deploy_database ;;
                5) initialize_database ;;
                6) deploy_application ;;
                7) deploy_ingress ;;
                8) deploy_monitoring ;;
                9) setup_argocd ;;
                10) verify_deployment ;;
                11) rollback ;;
                12) cleanup ;;
                0) 
                    log_info "Goodbye!"
                    exit 0 
                    ;;
                *) 
                    log_error "Invalid option"
                    ;;
            esac
        done
    else
        # Command line mode
        case $1 in
            deploy)
                create_namespace
                deploy_secrets
                deploy_database
                initialize_database
                deploy_application
                deploy_ingress
                deploy_monitoring
                setup_argocd
                verify_deployment
                ;;
            verify) verify_deployment ;;
            rollback) rollback ;;
            cleanup) cleanup ;;
            *)
                echo "Usage: $0 {deploy|verify|rollback|cleanup}"
                exit 1
                ;;
        esac
    fi
}

# Run main function
main "$@"