# Setup Guide

This guide will walk you through the process of setting up your Fabricator environment from scratch.

## Prerequisites

### Required Software

1. **Kubernetes Tools**
   - kubectl (latest stable version)
   - helm (v3.x or later)
   - task (latest version)

2. **Development Tools**
   - git
   - make
   - docker

### System Requirements

- Minimum 16GB RAM
- 4+ CPU cores
- 100GB+ available storage
- Linux-based system (tested on Ubuntu 20.04+)

## Installation Steps

### 1. Initial Setup

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd fabricator
   ```

2. Configure environment:
   ```bash
   cp .env.default .env
   ```

   Edit `.env` with your specific configurations:
   ```ini
   CLUSTER_NAME=homelab
   KUBERNETES_VERSION=1.26.0
   METALLB_IP_RANGE=192.168.1.240-192.168.1.250
   DOMAIN=home.lab
   ```

### 2. Bootstrap Process

1. Initialize the cluster:
   ```bash
   task lab-on
   ```

2. Verify cluster status:
   ```bash
   task lab-status
   ```

3. Deploy core components:
   ```bash
   task core
   ```

### 3. Component Configuration

#### Network Setup

1. **Cilium**
   - Network configuration will be automatically applied
   - Verify installation:
     ```bash
     cilium status
     ```

2. **MetalLB**
   - Configure IP address pool in `core/metallb/values.yaml`
   - Apply configuration:
     ```bash
     kubectl get pods -n metallb-system
     ```

3. **NGINX Ingress**
   - Default configuration will be applied
   - Check ingress controller:
     ```bash
     kubectl get pods -n ingress-nginx
     ```

#### Security Setup

1. **Cert Manager**
   - Configure issuers in `core/cert-manager/`
   - Verify installation:
     ```bash
     kubectl get pods -n cert-manager
     ```

2. **Sealed Secrets**
   - Generate new key pair (automatic)
   - Backup keys:
     ```bash
     kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key
     ```

3. **External Secrets**
   - Configure providers in `core/external-secrets/`
   - Verify operators:
     ```bash
     kubectl get pods -n external-secrets
     ```

#### GitOps Setup

1. **Argo CD**
   - Access UI: https://argocd.your.domain
   - Initial password:
     ```bash
     kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
     ```

## Post-Installation

### Verification

1. Check all components:
   ```bash
   kubectl get pods -A
   ```

2. Verify networking:
   ```bash
   cilium connectivity test
   ```

3. Test ingress:
   ```bash
   curl -k https://argocd.your.domain
   ```

### Security Hardening

1. Update default passwords
2. Configure network policies
3. Enable audit logging
4. Review RBAC configurations

### Backup Configuration

1. Set up regular backups:
   - Sealed Secrets keys
   - Cluster configuration
   - Persistent volumes

2. Document restore procedures

## Maintenance Procedures

### Regular Updates

1. Update core components:
   ```bash
   task core
   ```

2. Update Kubernetes:
   ```bash
   task lab-update
   ```

### Monitoring

1. Check cluster health:
   ```bash
   kubectl get nodes
   kubectl top nodes
   ```

2. Review logs:
   ```bash
   kubectl logs -n <namespace> <pod-name>
   ```

## Troubleshooting

### Common Issues

1. Cluster won't start
   - Check system resources
   - Verify network connectivity
   - Review task logs

2. Component failures
   - Check pod status
   - Review component logs
   - Verify configurations

### Support Resources

- Project Issues: GitHub Issues
- Documentation: `/docs` directory
- Community: [Link to community resources] 