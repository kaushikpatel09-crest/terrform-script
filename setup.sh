#!/bin/bash

# Setup script for Terraform AWS Infrastructure
# This script helps initialize and deploy the infrastructure

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed"
        echo "Install from: https://www.terraform.io/downloads"
        exit 1
    fi
    print_success "Terraform $(terraform version -json | jq -r '.terraform_version')"
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed"
        echo "Install from: https://aws.amazon.com/cli/"
        exit 1
    fi
    print_success "AWS CLI $(aws --version)"
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured"
        echo "Run: aws configure"
        exit 1
    fi
    print_success "AWS credentials configured"
    
    # Check jq
    if ! command -v jq &> /dev/null; then
        print_warning "jq is not installed (optional but recommended)"
    else
        print_success "jq installed"
    fi
}

# Initialize Terraform
init_terraform() {
    local environment=$1
    
    print_header "Initializing Terraform for $environment"
    
    # Prompt for S3 bucket and DynamoDB table
    read -p "Enter S3 bucket name for state: " s3_bucket
    read -p "Enter DynamoDB table name for locking: " dynamodb_table
    read -p "Enter AWS region (default: us-east-1): " aws_region
    aws_region=${aws_region:-us-east-1}
    
    cd terraform
    
    terraform init \
        -backend-config="bucket=$s3_bucket" \
        -backend-config="key=$environment/terraform.tfstate" \
        -backend-config="region=$aws_region" \
        -backend-config="dynamodb_table=$dynamodb_table" \
        -upgrade
    
    cd ..
    print_success "Terraform initialized"
}

# Validate configuration
validate_terraform() {
    print_header "Validating Terraform Configuration"
    
    cd terraform
    terraform fmt -check -recursive || terraform fmt -recursive
    terraform validate
    cd ..
    
    print_success "Configuration is valid"
}

# Plan deployment
plan_deployment() {
    local environment=$1
    
    print_header "Planning deployment for $environment"
    
    read -sp "Enter DocumentDB master password: " documentdb_password
    echo ""
    
    cd terraform
    terraform plan \
        -var-file="environments/$environment.tfvars" \
        -var="documentdb_master_password=$documentdb_password" \
        -out=tfplan \
        -no-color
    cd ..
    
    print_success "Plan saved to terraform/tfplan"
    echo ""
    print_warning "Review the plan above. To apply, run: $0 apply $environment"
}

# Apply deployment
apply_deployment() {
    local environment=$1
    
    print_header "Applying deployment for $environment"
    
    if [ ! -f "terraform/tfplan" ]; then
        print_error "No plan file found. Run 'plan' first."
        exit 1
    fi
    
    read -p "Are you sure you want to apply? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        print_warning "Apply cancelled"
        exit 0
    fi
    
    cd terraform
    terraform apply tfplan
    
    # Save outputs
    terraform output -json > ../outputs-$environment.json
    cd ..
    
    print_success "Deployment complete"
    echo "Outputs saved to outputs-$environment.json"
}

# Destroy deployment
destroy_deployment() {
    local environment=$1
    
    print_header "Destroying deployment for $environment"
    print_warning "This will delete all resources!"
    
    read -p "Type environment name to confirm (e.g., $environment): " confirm
    if [ "$confirm" != "$environment" ]; then
        print_warning "Destroy cancelled"
        exit 0
    fi
    
    read -sp "Enter DocumentDB master password: " documentdb_password
    echo ""
    
    cd terraform
    terraform destroy \
        -var-file="environments/$environment.tfvars" \
        -var="documentdb_master_password=$documentdb_password" \
        -auto-approve
    cd ..
    
    print_success "Resources destroyed"
}

# Show outputs
show_outputs() {
    local environment=$1
    
    print_header "Terraform Outputs for $environment"
    
    cd terraform
    terraform output -no-color
    cd ..
}

# Generate documentation
generate_docs() {
    print_header "Generating Documentation"
    
    cd terraform
    
    for module in modules/*/; do
        module_name=$(basename "$module")
        echo "Generating docs for $module_name module..."
        terraform-docs markdown table "$module" > "$module/README.md" 2>/dev/null || true
    done
    
    echo "Generating main documentation..."
    terraform-docs markdown table . > ../TERRAFORM.md 2>/dev/null || echo "terraform-docs not installed"
    
    cd ..
    print_success "Documentation generated"
}

# Show help
show_help() {
    cat << EOF
${BLUE}Terraform AWS Infrastructure Setup Script${NC}

Usage: $0 <command> [environment]

Commands:
    check       Check prerequisites
    init        Initialize Terraform backend
    validate    Validate Terraform configuration
    plan        Plan deployment
    apply       Apply deployment
    destroy     Destroy deployment
    output      Show Terraform outputs
    docs        Generate documentation
    help        Show this help message

Environments:
    dev         Development environment
    qa          QA environment
    stage       Stage environment

Examples:
    # Initial setup
    $0 check
    $0 init dev
    
    # Deploy to dev
    $0 validate
    $0 plan dev
    $0 apply dev
    
    # View outputs
    $0 output dev
    
    # Cleanup
    $0 destroy dev

EOF
}

# Main
main() {
    local command=${1:-help}
    local environment=${2:-dev}
    
    case "$command" in
        check)
            check_prerequisites
            ;;
        init)
            check_prerequisites
            init_terraform "$environment"
            ;;
        validate)
            validate_terraform
            ;;
        plan)
            plan_deployment "$environment"
            ;;
        apply)
            apply_deployment "$environment"
            ;;
        destroy)
            destroy_deployment "$environment"
            ;;
        output)
            show_outputs "$environment"
            ;;
        docs)
            generate_docs
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
