# Fabricator

A comprehensive home-lab infrastructure platform built on Kubernetes.

## Overview

Fabricator is a modern, GitOps-driven infrastructure platform designed for home labs. It provides enterprise-grade tools and practices in a manageable home environment setup.

### Key Features

- 🚀 One-command cluster deployment
- 🔒 Enterprise-grade security
- 🌐 Advanced networking with Cilium
- 📦 GitOps with Argo CD
- 🔑 Robust secret management
- 🔄 Automated certificate management

## Quick Start

```bash
# Clone the repository
git clone <repository-url>
cd fabricator

# Configure environment
cp .env.default .env
# Edit .env with your configurations

# Start the lab
task lab-on
```

## Documentation

Detailed documentation is available in the [docs](./docs) directory:

- [Setup Guide](./docs/setup-guide.md)
- [Core Components](./docs/core-components.md)
- [Main Documentation](./docs/README.md)

## Prerequisites

- Kubernetes cluster
- Helm 3.x
- Task runner
- 16GB+ RAM
- 4+ CPU cores
- 100GB+ storage

## License

This project is licensed under the terms of the [LICENSE](./LICENSE) file.

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting pull requests.
