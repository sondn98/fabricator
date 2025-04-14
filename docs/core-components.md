# Core Components Guide

This guide provides detailed information about each core component in the Fabricator infrastructure.

## Network Stack

### Cilium

Cilium provides networking, security, and observability for container workloads using eBPF technology.

#### Configuration
Located in: `core/cilium/`

Key features enabled:
- Container networking
- Network policies
- Load balancing
- Service mesh capabilities

### MetalLB

MetalLB provides network load balancing for bare metal Kubernetes clusters.

#### Configuration
Located in: `core/metallb/`

Setup includes:
- Layer 2 configuration
- IP address pool management
- BGP configuration (if applicable)

### NGINX Ingress Controller

Manages external access to services in the cluster.

#### Configuration
Located in: `core/nginx-ingress-controller/`

Features:
- HTTP/HTTPS routing
- SSL/TLS termination
- Load balancing
- Path-based routing

## Security Stack

### Cert Manager

Automates the management and issuance of TLS certificates.

#### Configuration
Located in: `core/cert-manager/`

Capabilities:
- Let's Encrypt integration
- Custom certificate issuers
- Certificate lifecycle management

### Sealed Secrets

Enables secure GitOps by encrypting Kubernetes secrets.

#### Configuration
Located in: `core/sealed-secrets/`

Features:
- One-way encrypted secrets
- GitOps compatibility
- Key rotation

### External Secrets

Manages secrets from external providers.

#### Configuration
Located in: `core/external-secrets/`

Supported providers:
- AWS Secrets Manager
- HashiCorp Vault
- Azure Key Vault
- GCP Secret Manager

## Deployment Stack

### Argo CD

GitOps continuous delivery tool for Kubernetes.

#### Configuration
Located in: `core/argo-cd/`

Features:
- Application deployment
- Configuration management
- Health monitoring
- Rollback capabilities

## Configuration Management

### Helm Charts

All components are managed via Helm charts, configured in `core/helmfile.yaml`.

Example configuration:
```yaml
repositories:
  - name: bitnami
    url: https://charts.bitnami.com/bitnami

releases:
  - name: cert-manager
    namespace: cert-manager
    chart: jetstack/cert-manager
    version: v1.x.x
```

## Monitoring and Logging

TBD: Document monitoring and logging setup

## Security Considerations

1. Network Security
   - All internal communication is encrypted
   - Network policies restrict pod-to-pod communication
   - Ingress traffic is filtered and monitored

2. Secret Management
   - Secrets are encrypted at rest
   - Access is controlled via RBAC
   - Regular key rotation is implemented

## Best Practices

1. Configuration
   - Use version-controlled Helm values
   - Implement proper namespacing
   - Follow least-privilege principle

2. Maintenance
   - Regular updates of components
   - Backup of critical configurations
   - Monitoring of resource usage

## Troubleshooting Guide

### Common Issues

1. Certificate Issues
   ```bash
   kubectl get challenges -A
   kubectl describe certificate -n <namespace>
   ```

2. Network Problems
   ```bash
   cilium status
   cilium connectivity test
   ```

3. Ingress Issues
   ```bash
   kubectl get ingress -A
   kubectl describe ingress -n <namespace>
   ``` 