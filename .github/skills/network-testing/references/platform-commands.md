# Platform Commands Reference

This reference maps common network validation tasks to the correct show commands, parser names, and output key paths for each supported platform. Copilot must consult this when generating tests to ensure platform-correct code.

## Command Mapping

### Software Version

| Platform | Command | Parser Output Key Path |
|----------|---------|----------------------|
| NX-OS | `show version` | `output['platform']['software']['system_version']` |
| IOS-XE | `show version` | `output['version']['version']` |
| IOS-XR | `show version` | `output['software_version']` |

**Example extracted values:** `10.3(1)`, `17.09.04a`, `7.9.2`

### BGP Summary

| Platform | Command | Parser Output Key Path |
|----------|---------|----------------------|
| NX-OS | `show bgp all summary` (preferred), `show bgp ipv4 unicast summary`, `show bgp vrf all all summary`, `show bgp vrf all summary` | `output['vrf'][<vrf>]['neighbor'][<ip>]['state_pfxrcd']` |
| IOS-XE | `show bgp all summary` | `output['vrf'][<vrf>]['neighbor'][<ip>]['state_pfxrcd']` |
| IOS-XR | `show bgp summary` | `output['instance']['default']['vrf']['default']['neighbor'][<ip>]['session_state']` |

**Healthy states:** A numeric value (prefix count) indicates established. Text values (`Idle`, `Active`, `Connect`, `OpenSent`, `OpenConfirm`) indicate the session is NOT established.

**Parser coverage note:** If `ParserNotFound` occurs, retry parser candidates for the same platform before falling back to controlled text extraction.

### BGP Neighbors (Detailed)

| Platform | Command | Parser Output Key Path |
|----------|---------|----------------------|
| NX-OS | `show bgp vrf all all neighbors` | `output['neighbor'][<ip>]['session_state']` |
| IOS-XE | `show bgp all neighbors` | `output['list_of_neighbors'][<idx>]['bgp_session_transport']['connection']['state']` |
| IOS-XR | `show bgp neighbors` | `output['neighbor'][<ip>]['session_state']` |

### OSPF Neighbors

| Platform | Command | Parser Output Key Path |
|----------|---------|----------------------|
| NX-OS | `show ip ospf neighbors detail` | `output['vrf'][<vrf>]['address_family']['ipv4']['instance'][<id>]['areas'][<area>]['interfaces'][<intf>]['neighbors'][<ip>]['state']` |
| IOS-XE | `show ip ospf neighbor detail` | `output['vrf'][<vrf>]['address_family']['ipv4']['instance'][<id>]['areas'][<area>]['interfaces'][<intf>]['neighbors'][<ip>]['state']` |
| IOS-XR | `show ospf neighbor detail` | `output['vrf'][<vrf>]['<instance>']['areas'][<area>]['interfaces'][<intf>]['neighbors'][<ip>]['state']` |

**Expected state:** `Full` (for DR/BDR adjacencies) or `2-Way` (on broadcast segments without DR/BDR role)

### ISIS Neighbors

| Platform | Command | Parser Output Key Path |
|----------|---------|----------------------|
| NX-OS | `show isis adjacency` | `output['isis'][<instance>]['vrf'][<vrf>]['interfaces'][<intf>]['adjacencies'][<system_id>]['state']` |
| IOS-XE | `show isis neighbors` | `output['isis'][<instance>]['vrf'][<vrf>]['interfaces'][<intf>]['adjacencies'][<system_id>]['state']` |
| IOS-XR | `show isis neighbors` | `output['isis'][<instance>]['vrf'][<vrf>]['interfaces'][<intf>]['adjacencies'][<system_id>]['state']` |

**Expected state:** `Up`

### Interface Status

| Platform | Command | Parser Output Key Path |
|----------|---------|----------------------|
| NX-OS | `show interface` | `output[<intf>]['enabled']` (bool), `output[<intf>]['oper_status']` |
| IOS-XE | `show interfaces` | `output[<intf>]['enabled']` (bool), `output[<intf>]['oper_status']` |
| IOS-XR | `show interfaces` | `output[<intf>]['enabled']` (bool), `output[<intf>]['oper_status']` |

**Expected values:** `enabled: True`, `oper_status: 'up'`

### Interface Error Counters

| Platform | Command | Key Counters |
|----------|---------|-------------|
| NX-OS | `show interface` | `output[<intf>]['counters']['in_errors']`, `out_errors`, `in_crc_errors` |
| IOS-XE | `show interfaces` | `output[<intf>]['counters']['in_errors']`, `out_errors`, `in_crc_errors` |
| IOS-XR | `show interfaces` | `output[<intf>]['counters']['in_errors']`, `out_errors`, `in_crc_errors` |

### CPU Utilization

| Platform | Command | Parser Output Key Path |
|----------|---------|----------------------|
| NX-OS | `show processes cpu` | `output['five_min_cpu']` |
| IOS-XE | `show processes cpu` | `output['five_min_cpu']` |
| IOS-XR | `show processes cpu` | `output['five_min_cpu']` |

**Threshold:** Typically alert if > 80%

### Memory Utilization

| Platform | Command | Parser Output Key Path |
|----------|---------|----------------------|
| NX-OS | `show system resources` | `output['memory_usage_total']`, `output['memory_usage_used']` |
| IOS-XE | `show processes memory` | `output['processor_pool']['total']`, `output['processor_pool']['used']` |
| IOS-XR | `show memory summary` | `output['node'][<node>]['physical_memory']`, `output['node'][<node>]['free_physical_memory']` |

### Environment / Hardware Health

| Platform | Command | Parser Output Key Path |
|----------|---------|----------------------|
| NX-OS | `show environment` | `output['fans'][<fan>]['status']`, `output['powersupply'][<ps>]['status']` |
| IOS-XE | `show environment all` | `output['sensor_list'][<idx>]['state']` |
| IOS-XR | `show environment` | `output['module'][<mod>]['sensor'][<sensor>]['state']` |

**Expected values:** Statuses containing `Ok`, `Normal`, `Green`

### Routing Table

| Platform | Command | Parser Output Key Path |
|----------|---------|----------------------|
| NX-OS | `show ip route vrf all` | `output['vrf'][<vrf>]['address_family']['ipv4']['routes'][<prefix>]['active']` |
| IOS-XE | `show ip route` | `output['vrf'][<vrf>]['address_family']['ipv4']['routes'][<prefix>]['active']` |
| IOS-XR | `show route ipv4` | `output['vrf'][<vrf>]['address_family']['ipv4']['routes'][<prefix>]['active']` |

## Configuration Commands

### Interface Shutdown

| Platform | Command Sequence |
|----------|-----------------|
| NX-OS | `configure terminal`, `interface <intf>`, `shutdown`, `end` |
| IOS-XE | `configure terminal`, `interface <intf>`, `shutdown`, `end` |
| IOS-XR | `configure terminal`, `interface <intf>`, `shutdown`, `commit`, `end` |

**Note:** IOS-XR requires an explicit `commit` after configuration changes.

### Interface No Shutdown (Restore)

| Platform | Command Sequence |
|----------|-----------------|
| NX-OS | `configure terminal`, `interface <intf>`, `no shutdown`, `end` |
| IOS-XE | `configure terminal`, `interface <intf>`, `no shutdown`, `end` |
| IOS-XR | `configure terminal`, `interface <intf>`, `no shutdown`, `commit`, `end` |

### Clear BGP Sessions

| Platform | Command |
|----------|---------|
| NX-OS | `clear ip bgp *` |
| IOS-XE | `clear ip bgp *` |
| IOS-XR | `clear bgp all all graceful` |

### Clear OSPF Process

| Platform | Command |
|----------|---------|
| NX-OS | `clear ip ospf process *` (then confirm with `y`) |
| IOS-XE | `clear ip ospf process` (then confirm with `yes`) |
| IOS-XR | `clear ospf process` |

## Platform Detection Pattern

Use the testbed `os` field to determine the platform:

```python
testbed = loader.load(testbed_file)
device = testbed.devices[device_name]
platform = device.os  # Returns: 'nxos', 'iosxe', or 'iosxr'
```

When generating tests that must work across platforms, use a command-candidate dispatch pattern:

```python
from genie.libs.parser.utils.common import ParserNotFound

COMMAND_CANDIDATES = {
    'nxos': {
    'bgp_summary': [
      'show bgp all summary',
      'show bgp ipv4 unicast summary',
      'show bgp vrf all all summary',
      'show bgp vrf all summary',
    ],
        'version': 'show version',
    },
    'iosxe': {
    'bgp_summary': ['show bgp all summary', 'show bgp ipv4 unicast summary'],
        'version': 'show version',
    },
    'iosxr': {
    'bgp_summary': ['show bgp summary'],
        'version': 'show version',
    },
}

output = None
for command in COMMAND_CANDIDATES[device.os]['bgp_summary']:
  try:
    output = device.parse(command)
    break
  except ParserNotFound:
    continue

if output is None:
  raw_output = device.execute(COMMAND_CANDIDATES[device.os]['bgp_summary'][0])
  # Extract only required fields from raw output.
```

## NETCONF Connections

pyATS supports NETCONF as an alternative to CLI. Use NETCONF for structured data retrieval and configuration changes via YANG models.

### Testbed NETCONF Configuration

```yaml
devices:
  iosxe-router-1:
    os: iosxe
    connections:
      cli:
        protocol: ssh
        ip: 198.18.134.201
      netconf:
        class: unicon.Unicon
        protocol: netconf
        ip: 198.18.134.201
        port: 830
```

### Connecting via NETCONF

```python
# Connect using the NETCONF connection alias
device.connect(alias='netconf', via='netconf', log_stdout=False)

# Execute a NETCONF get operation
from genie.libs.sdk.apis.utils import get_running_config_section
output = device.netconf.get_config(source='running')
```

### Common NETCONF Operations by Platform

| Platform | NETCONF Support | Default Port | Notes |
|----------|----------------|-------------|-------|
| NX-OS | Yes (must enable `feature netconf`) | 830 | Supports OpenConfig and native YANG models |
| IOS-XE | Yes (enabled by default on modern versions) | 830 | Broadest YANG model support |
| IOS-XR | Yes (enabled by default) | 830 | Native YANG and OpenConfig |

### NETCONF Get Example

```python
from ncclient import manager

def get_interfaces_netconf(testbed_file, device_name):
    """Get interface data via NETCONF."""
    device = None
    try:
        testbed = loader.load(testbed_file)
        device = testbed.devices[device_name]
        device.connect(alias='netconf', via='netconf', log_stdout=False)

        # Use Genie NETCONF get
        interfaces = device.parse('show interfaces', connection_alias='netconf')
        return interfaces
    except Exception as e:
        raise RuntimeError(f"Failed NETCONF query on {device_name}: {e}") from e
    finally:
        if device and device.is_connected(alias='netconf'):
            device.disconnect_from('netconf')
```

## REST API (RESTCONF) Connections

RESTCONF provides a RESTful interface to YANG models over HTTPS. Useful for programmatic configuration validation and when CLI parsers are unavailable.

### Testbed RESTCONF Configuration

```yaml
devices:
  iosxe-router-1:
    os: iosxe
    connections:
      cli:
        protocol: ssh
        ip: 198.18.134.201
      rest:
        class: rest.connector.Rest
        ip: 198.18.134.201
        port: 443
        protocol: https
        credentials:
          rest:
            username: "%ENV{PYATS_USERNAME}"
            password: "%ENV{PYATS_PASSWORD}"
```

### Common RESTCONF Endpoints by Platform

| Platform | Base URL | Auth | Notes |
|----------|----------|------|-------|
| NX-OS | `https://<ip>/restconf/data/` | Basic Auth or Token | Requires `feature restconf` + NX-API |
| IOS-XE | `https://<ip>/restconf/data/` | Basic Auth | Requires `ip http secure-server` + `restconf` |
| IOS-XR | `https://<ip>/restconf/data/` | Basic Auth | Requires `http server` config |

### RESTCONF Helper Pattern

```python
import requests
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

def get_interfaces_restconf(testbed_file, device_name):
    """Get interface operational data via RESTCONF."""
    device = None
    try:
        testbed = loader.load(testbed_file)
        device = testbed.devices[device_name]
        device.connect(alias='rest', via='rest', log_stdout=False)

        output = device.rest.get(
            '/restconf/data/ietf-interfaces:interfaces'
        )
        return output.json()
    except Exception as e:
        raise RuntimeError(f"Failed RESTCONF query on {device_name}: {e}") from e
    finally:
        if device and device.is_connected(alias='rest'):
            device.disconnect_from('rest')
```

### Key RESTCONF YANG Paths

| Data | YANG Path | Standard |
|------|-----------|----------|
| Interfaces | `/restconf/data/ietf-interfaces:interfaces` | IETF |
| Interface state | `/restconf/data/ietf-interfaces:interfaces-state` | IETF |
| BGP config | `/restconf/data/openconfig-network-instance:network-instances` | OpenConfig |
| Routing table | `/restconf/data/ietf-routing:routing` | IETF |
| System info | `/restconf/data/openconfig-system:system` | OpenConfig |
| ACLs | `/restconf/data/openconfig-acl:acl` | OpenConfig |

### Connection Method Selection Guide

| Scenario | Recommended Method | Reason |
|----------|-------------------|--------|
| Show command validation | **CLI** (`device.parse()`) | Best parser coverage via Genie |
| Configuration retrieval/comparison | **NETCONF** | Structured YANG data, no parsing needed |
| Programmatic config validation | **RESTCONF** | Easy JSON response, standard YANG paths |
| Bulk operational data | **CLI** | Fastest for multi-command sequences |
| Config change + commit | **NETCONF** | Transactional, supports candidate config |
| Integration with external tools | **RESTCONF** | Standard HTTP, easy to integrate |

## Common Parser Gotchas

1. **NX-OS `show version`** returns version under `platform.software.system_version`, not `version.version`
2. **IOS-XR BGP** uses `instance.default.vrf.default` nesting that NX-OS and IOS-XE don't have
3. **IOS-XR config requires `commit`** — forgetting this means changes are not applied
4. **Empty parser output** — if a feature is not configured (e.g., no BGP), the parser raises `SchemaEmptyParserError`. Always handle this:
   ```python
   from genie.metaparser.util.exceptions import SchemaEmptyParserError
   
   try:
       output = device.parse('show bgp all summary')
   except SchemaEmptyParserError:
       return {}  # No BGP configured
   ```
5. **Interface naming** differs: NX-OS uses `Ethernet1/1`, IOS-XE uses `GigabitEthernet0/0/0`, IOS-XR uses `GigabitEthernet0/0/0/0`
6. **NETCONF connection alias** — always specify `alias='netconf'` and `via='netconf'` when connecting. Disconnect with `device.disconnect_from('netconf')`, not `device.disconnect()`
7. **RESTCONF HTTPS** — most lab devices use self-signed certificates. Disable SSL verification in test environments only. Never disable in production.
8. **REST connector** — requires `pip install rest.connector` in addition to `pyats[full]`
