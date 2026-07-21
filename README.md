# Fabricator Documentation

Welcome to Fabricator - A Comprehensive Home Lab Infrastructure Platform

## Overview

Fabricator is a sophisticated home-lab infrastructure management platform built on Kubernetes. It provides a complete stack for running and managing a home lab environment with enterprise-grade tools and practices.

## Architecture

### Core Components

1. **Network Layer**
   - Cilium: Advanced networking with eBPF
   - MetalLB: Bare metal load balancing
   - NGINX Ingress Controller: Traffic management

2. **Security Layer**
   - Cert Manager: Certificate automation
   - Sealed Secrets: Secure secret management
   - External Secrets: External secrets integration

3. **Deployment Layer**
   - Argo CD: GitOps continuous delivery
   - Helm: Package management

## Directory Structure

```
fabricator/
├── bootstrap/       # Initial setup and bootstrapping
├── clusters/        # Cluster-specific configurations
├── core/           # Core infrastructure components
├── design/         # Design documents and specifications
├── docs/           # Documentation (you are here)
├── platforms/      # Platform-specific configurations
└── provisioning/   # Infrastructure provisioning
```

## Getting Started

### Prerequisites

- Kubernetes cluster
- Helm 3.x
- Task (task runner)
- Required environment variables in `.env` file

### Quick Start

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd fabricator
   ```

2. Copy and configure environment variables:
   ```bash
   cp .env.default .env
   # Edit .env with your configurations
   ```

3. Start the lab:
   ```bash
   task lab-on
   ```

### Available Commands

- `task lab-on`: Start the lab infrastructure
- `task lab-off`: Shutdown the lab
- `task lab-status`: Check lab status
- `task lab-delete`: Delete the lab environment
- `task core`: Apply core infrastructure components

## Component Details

### Core Infrastructure

The core infrastructure is managed through Helm charts and includes:

1. **Cilium**
   - Network policy enforcement
   - Container networking
   - Load balancing

2. **MetalLB**
   - Layer 2 load balancing
   - IP address management

3. **NGINX Ingress Controller**
   - HTTP/HTTPS routing
   - TLS termination
   - Load balancing

4. **Cert Manager**
   - Automatic TLS certificate management
   - Let's Encrypt integration

5. **Sealed Secrets**
   - Kubernetes secret encryption
   - GitOps-friendly secret management

6. **External Secrets**
   - External secret store integration
   - Secure secret management

7. **Argo CD**
   - GitOps continuous delivery
   - Application lifecycle management

## Maintenance

### Backup and Recovery

TBD: Document backup and recovery procedures

### Upgrading

TBD: Document upgrade procedures for various components

### Troubleshooting

Common issues and their solutions:

1. Cluster startup issues
   - Check network connectivity
   - Verify environment variables
   - Review component logs

2. Component failures
   - Check component status: `kubectl get pods -A`
   - Review logs: `kubectl logs -n <namespace> <pod-name>`

## Contributing

Guidelines for contributing to Fabricator:

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## License

See the [LICENSE](../LICENSE) file for details. 