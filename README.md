# BGP Failover and Health Check Automation

Network automation test suite for validating BGP failover behavior, convergence, and neighbor health across NX-OS devices using pyATS, Genie, and Robot Framework.

## Overview

This repository contains automated tests designed to validate:
- **BGP Failover Convergence**: Measure BGP convergence time during link failures
- **BGP Neighbor Health**: Monitor BGP neighbor states and operational metrics
- **Interface Validation**: Verify interface states and configurations via RESTCONF

Tests are built on industry-standard frameworks for network device testing and can be integrated into CI/CD pipelines.

## Project Structure

```
.
├── README.md                          # This file
├── requirements.txt                   # Python dependencies
├── testbed/
│   └── nexus_testbed.yaml            # Testbed definition for NX-OS devices
├── tests/
│   ├── bgp_bdd_failover.robot        # BDD-style BGP failover test
│   ├── bgp_failover_convergence.robot # BGP convergence measurement test
│   ├── bgp_neighbor_health.py         # pyATS BGP neighbor health checks
│   ├── bgp_neighbor_health.robot      # Robot Framework BGP health test
│   ├── interface_validation_restconf.robot # RESTCONF interface validation
│   ├── helper.py                      # Python helper functions
│   └── keywords.robot                 # Custom Robot Framework keywords
└── .github/
    ├── instructions/                  # Security and design guidelines
    └── skills/network-testing/        # Reusable test patterns and documentation
```

## Requirements

- **Python 3.7+**
- **pyATS** - Network test automation framework
- **Genie** - Network data models and parsing
- **Robot Framework** - Test automation framework
- **Requests** - HTTP library for RESTCONF calls

Install dependencies:
```bash
pip install -r requirements.txt
```

## Setup

### 1. Configure Your Testbed

Edit `testbed/nexus_testbed.yaml` with your NX-OS device details:
```yaml
devices:
  nxos-spine-1:
    os: nxos
    platform: n9k
    credentials:
      default:
        username: "%ENV{PYATS_USERNAME}%"
        password: "%ENV{PYATS_PASSWORD}%"
    connections:
      cli:
        protocol: ssh
        ip: <your-device-ip>
        port: 22
```

### 2. Set Environment Variables

Before running tests, set your device credentials:
```bash
export PYATS_USERNAME=admin
export PYATS_PASSWORD=<your-password>
```

**Important**: Never commit real credentials to version control. Use environment variables or secure credential stores.

## Running Tests

### Run All Tests
```bash
# Robot Framework tests
robot tests/

# pyATS tests
python -m pytest tests/bgp_neighbor_health.py -v
```

### Run Specific Test Suite
```bash
# BGP neighbor health checks
robot tests/bgp_neighbor_health.robot

# BGP failover convergence
robot tests/bgp_failover_convergence.robot

# Interface validation
robot tests/interface_validation_restconf.robot
```

### Run with Testbed
```bash
robot --variable TESTBED:testbed/nexus_testbed.yaml tests/bgp_neighbor_health.robot
```

## Test Descriptions

### `bgp_neighbor_health.robot` & `bgp_neighbor_health.py`
Validates BGP neighbor operational state across the topology:
- Neighbor state (Established, Active, etc.)
- Prefix counts and statistics
- Session uptime

### `bgp_failover_convergence.robot`
Measures BGP convergence time during link failures:
- Triggers link failure
- Monitors convergence time
- Validates reroute correctness

### `bgp_bdd_failover.robot`
Behavior-Driven Development (BDD) style tests for failover scenarios:
- Gherkin syntax for business-readable tests
- Step-by-step failover validation

### `interface_validation_restconf.robot`
RESTCONF-based interface state validation:
- Verifies interface operational state
- Checks bandwidth and speed configurations
- Validates MTU settings

## Key Features

✅ **Multi-Device Support**: Tests across spine, leaf, and border leaf devices  
✅ **Multiple Protocols**: CLI, NETCONF, and RESTCONF connectivity options  
✅ **Convergence Timing**: Accurate BGP failover convergence measurement  
✅ **Reusable Keywords**: Custom Robot Framework keywords for common operations  
✅ **Helper Functions**: Python utilities for device interaction  
✅ **Clear Reporting**: Detailed test reports with device state snapshots  

## Security Considerations

- Credentials are **environment-variable based**, never hardcoded
- HTTPS/NETCONF recommended for production use
- Test environment should be isolated and non-production
- Review `.github/instructions/` for security best practices

## CI/CD Integration

Example GitHub Actions workflow:
```yaml
- name: Run Network Tests
  env:
    PYATS_USERNAME: ${{ secrets.PYATS_USERNAME }}
    PYATS_PASSWORD: ${{ secrets.PYATS_PASSWORD }}
  run: |
    pip install -r requirements.txt
    robot tests/
```

## Troubleshooting

**Connection Timeout**
- Verify device IP and SSH port in testbed
- Check network reachability: `ping <device-ip>`
- Ensure credentials are correct

**Authentication Failed**
- Verify `PYATS_USERNAME` and `PYATS_PASSWORD` are set
- Confirm user has proper privileges on devices

**Missing Dependencies**
```bash
pip install --upgrade -r requirements.txt
```

## Contributing

1. Create a feature branch: `git checkout -b feature/test-name`
2. Add tests following existing patterns
3. Test locally before submitting
4. Commit and push to GitHub

## References

- [pyATS Documentation](https://pubhub.devnetcloud.com/media/pyats/docs/)
- [Genie Documentation](https://pubhub.devnetcloud.com/media/genie-docs/)
- [Robot Framework User Guide](https://robotframework.org/)
- [RESTCONF RFC 8040](https://tools.ietf.org/html/rfc8040)

## License

[Add your license information here]

## Support

For issues or questions, open an issue on GitHub or contact the team.
