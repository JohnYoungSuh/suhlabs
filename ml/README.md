# SuhLabs ML Features

Production-grade ML features for zero-cloud, self-hosted LLM infrastructure.

## Features

### CCF-ZKCS: Cryptographic Context Fingerprinting for Zero-Copy KV-Cache Sharing

**Status**: ✅ Production-ready

Reduces LLM inference compute by 40-65% through cryptographic KV-cache deduplication.

- **Documentation**: [features/ccf_zkcs/README.md](features/ccf_zkcs/README.md)
- **Tests**: [tests/ccf_zkcs/](tests/ccf_zkcs/)
- **Deployment**: [../ansible/playbooks/deploy_ccf_zkcs.yml](../ansible/playbooks/deploy_ccf_zkcs.yml)

**Key Benefits**:
- 40-65% compute reduction vs baseline
- 35-50% memory savings
- 100% deterministic (idempotent)
- Zero-cloud, mTLS enforced

**Quick Start**:
```bash
# Deploy
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/deploy_ccf_zkcs.yml

# Test
pytest ml/tests/ccf_zkcs/ -v

# Monitor
curl https://ml-server:8443/metrics
```

## Architecture

```
ml/
├── features/              # ML feature implementations
│   └── ccf_zkcs/         # CCF-ZKCS feature
│       ├── handler.py    # Main handler
│       ├── cache_manager.py
│       ├── merkle_dag.py
│       ├── config.py
│       ├── Modelfile     # Ollama integration
│       └── README.md     # Full documentation
├── common/               # Shared utilities
│   ├── vault_client.py  # Vault integration with mTLS
│   └── tls_context.py   # TLS context wrapper
├── tests/                # Test suites
│   └── ccf_zkcs/        # CCF-ZKCS tests
│       ├── test_*.py    # Antipattern tests
│       └── integration/ # Integration tests
└── requirements.txt      # Python dependencies
```

## Stack Compatibility

- **Python**: 3.10+
- **Ollama**: v0.1.29+
- **Qdrant**: v1.7+
- **Vault**: v1.13+
- **FastAPI**: v0.100+

## Security

All features enforce:
- ✅ mTLS for all network operations
- ✅ Vault-only secret storage
- ✅ cert-manager certificate lifecycle
- ✅ HMAC integrity verification
- ✅ Bounded resource usage

## Contributing

1. Create feature in `features/{name}/`
2. Add tests in `tests/{name}/`
3. Document in `features/{name}/README.md`
4. Add Ansible deployment playbook
5. Add Prometheus alerts

## License

Apache 2.0 - See [../LICENSE](../LICENSE)
