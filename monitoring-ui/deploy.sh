#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="thesauros-monitoring"
DOCKER_REGISTRY="ghcr.io"
IMAGE_NAME="$DOCKER_REGISTRY/$PROJECT_NAME"
TAG=$(git rev-parse --short HEAD)

echo -e "${GREEN}🚀 Starting deployment of Thesauros Monitoring Service${NC}"

# Check if required tools are installed
check_requirements() {
    echo -e "${YELLOW}Checking requirements...${NC}"
    
    command -v docker >/dev/null 2>&1 || { echo -e "${RED}Docker is required but not installed.${NC}" >&2; exit 1; }
    command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}kubectl is required but not installed.${NC}" >&2; exit 1; }
    command -v terraform >/dev/null 2>&1 || { echo -e "${RED}Terraform is required but not installed.${NC}" >&2; exit 1; }
    
    echo -e "${GREEN}✅ All requirements met${NC}"
}

# Build Docker image
build_image() {
    echo -e "${YELLOW}Building Docker image...${NC}"
    
    docker build -t $IMAGE_NAME:$TAG .
    docker tag $IMAGE_NAME:$TAG $IMAGE_NAME:latest
    
    echo -e "${GREEN}✅ Docker image built successfully${NC}"
}

# Push Docker image
push_image() {
    echo -e "${YELLOW}Pushing Docker image...${NC}"
    
    docker push $IMAGE_NAME:$TAG
    docker push $IMAGE_NAME:latest
    
    echo -e "${GREEN}✅ Docker image pushed successfully${NC}"
}

# Deploy to Kubernetes
deploy_k8s() {
    echo -e "${YELLOW}Deploying to Kubernetes...${NC}"
    
    # Update image tag in deployment
    sed -i.bak "s|image: .*|image: $IMAGE_NAME:$TAG|" k8s/deployment.yaml
    
    # Apply Kubernetes manifests
    kubectl apply -f k8s/secrets.yaml
    kubectl apply -f k8s/deployment.yaml
    
    # Wait for deployment to be ready
    kubectl rollout status deployment/thesauros-monitoring --timeout=300s
    
    echo -e "${GREEN}✅ Kubernetes deployment successful${NC}"
}

# Verify deployment
verify_deployment() {
    echo -e "${YELLOW}Verifying deployment...${NC}"
    
    # Check pods
    kubectl get pods -l app=thesauros-monitoring
    
    # Check services
    kubectl get services -l app=thesauros-monitoring
    
    # Check ingress
    kubectl get ingress -l app=thesauros-monitoring
    
    echo -e "${GREEN}✅ Deployment verification complete${NC}"
}

# Main deployment flow
main() {
    check_requirements
    
    if [ "$1" = "build-only" ]; then
        build_image
        echo -e "${GREEN}Build completed successfully${NC}"
        exit 0
    fi
    
    if [ "$1" = "push-only" ]; then
        push_image
        echo -e "${GREEN}Push completed successfully${NC}"
        exit 0
    fi
    
    if [ "$1" = "deploy-only" ]; then
        deploy_k8s
        verify_deployment
        echo -e "${GREEN}Deployment completed successfully${NC}"
        exit 0
    fi
    
    # Full deployment
    build_image
    push_image
    deploy_k8s
    verify_deployment
    
    echo -e "${GREEN}🎉 Full deployment completed successfully!${NC}"
    echo -e "${YELLOW}Your monitoring service should be available at:${NC}"
    echo -e "${GREEN}https://monitoring.your-domain.com${NC}"
}

# Run main function with all arguments
main "$@"
