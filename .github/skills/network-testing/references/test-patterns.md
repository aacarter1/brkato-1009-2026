# Network Test Patterns Reference

Reusable test patterns for common network validation scenarios. Each pattern includes a Python helper template, Robot Framework keyword, and test case. Copilot should select and adapt these patterns based on the user's request.

---

## Pattern 1: Software Version Validation

**Use when:** Verifying devices are running the expected software version after an upgrade or as a compliance check.

### Helper Function
```python
def get_software_version(testbed_file, device_name):
    """Get the running software version from a network device."""
    device = None
    try:
        testbed = loader.load(testbed_file)
        device = testbed.devices[device_name]
        device.connect(log_stdout=False)

        output = device.parse('show version')

        # Platform-specific extraction
        if device.os == 'nxos':
            return output['platform']['software']['system_version']
        elif device.os == 'iosxe':
            return output['version']['version']
        elif device.os == 'iosxr':
            return output['software_version']
    except Exception as e:
        raise RuntimeError(f"Failed to get version from {device_name}: {e}") from e
    finally:
        if device and device.is_connected():
            device.disconnect()
```

### Robot Keyword
```robot
Get Software Version
    [Documentation]    Returns the running software version for the specified device
    [Arguments]    ${testbed}    ${device}
    ${version}=    Get Software Version    ${testbed}    ${device}
    RETURN    ${version}
```

### Test Case
```robot
Device Is Running Expected Software Version
    [Documentation]    Validates the device is running the target software version
    [Tags]    version    compliance    critical
    ${version}=    Get Software Version    ${testbed}    ${device}
    Should Contain    ${version}    ${expected_version}
    ...    msg=${device} is running ${version}, expected ${expected_version}
```

---

## Pattern 2: Routing Protocol Neighbor Health

**Use when:** Validating that all BGP, OSPF, or ISIS neighbors are in a healthy state.

### Helper Function (BGP)
```python
def get_bgp_neighbor_states(testbed_file, device_name):
    """Get all BGP neighbor states. Returns dict of {neighbor_ip: state}."""
    from genie.metaparser.util.exceptions import SchemaEmptyParserError

    device = None
    try:
        testbed = loader.load(testbed_file)
        device = testbed.devices[device_name]
        device.connect(log_stdout=False)

        command = 'show bgp summary' if device.os == 'iosxr' else 'show bgp all summary'

        try:
            output = device.parse(command)
        except SchemaEmptyParserError:
            return {}

        neighbor_states = {}
        if device.os == 'iosxr':
            for vrf_data in output.get('instance', {}).get('default', {}).get('vrf', {}).values():
                for neighbor, details in vrf_data.get('neighbor', {}).items():
                    neighbor_states[neighbor] = details.get('session_state', 'Unknown')
        else:
            for vrf_data in output.get('vrf', {}).values():
                for neighbor, details in vrf_data.get('neighbor', {}).items():
                    neighbor_states[neighbor] = details.get('state_pfxrcd', 'Unknown')

        return neighbor_states
    except Exception as e:
        raise RuntimeError(f"Failed to get BGP neighbors on {device_name}: {e}") from e
    finally:
        if device and device.is_connected():
            device.disconnect()
```

### Helper Function (OSPF)
```python
def get_ospf_neighbor_states(testbed_file, device_name):
    """Get all OSPF neighbor states. Returns dict of {neighbor_ip: state}."""
    from genie.metaparser.util.exceptions import SchemaEmptyParserError

    device = None
    try:
        testbed = loader.load(testbed_file)
        device = testbed.devices[device_name]
        device.connect(log_stdout=False)

        command = 'show ospf neighbor detail' if device.os == 'iosxr' else 'show ip ospf neighbor detail'

        try:
            output = device.parse(command)
        except SchemaEmptyParserError:
            return {}

        neighbor_states = {}
        for vrf_data in output.get('vrf', {}).values():
            for instance_data in vrf_data.get('address_family', {}).get('ipv4', {}).get('instance', {}).values():
                for area_data in instance_data.get('areas', {}).values():
                    for intf_data in area_data.get('interfaces', {}).values():
                        for neighbor_ip, details in intf_data.get('neighbors', {}).items():
                            neighbor_states[neighbor_ip] = details.get('state', 'Unknown')

        return neighbor_states
    except Exception as e:
        raise RuntimeError(f"Failed to get OSPF neighbors on {device_name}: {e}") from e
    finally:
        if device and device.is_connected():
            device.disconnect()
```

### Test Case (BGP)
```robot
All BGP Neighbors Are Established
    [Documentation]    Validates no BGP neighbors are in Idle, Active, or Connect state
    [Tags]    bgp    critical    routing
    ${neighbors}=    Get BGP Neighbor States    ${testbed}    ${device}
    Should Not Be Empty    ${neighbors}    msg=No BGP neighbors found on ${device}
    FOR    ${neighbor}    ${state}    IN    &{neighbors}
        Should Not Match Regexp    ${state}    ^(Idle|Active|Connect|OpenSent|OpenConfirm)$
        ...    msg=BGP neighbor ${neighbor} is not established (state: ${state})
    END
```

### Test Case (OSPF)
```robot
All OSPF Neighbors Are Full
    [Documentation]    Validates all OSPF adjacencies are in Full state
    [Tags]    ospf    critical    routing
    ${neighbors}=    Get OSPF Neighbor States    ${testbed}    ${device}
    Should Not Be Empty    ${neighbors}    msg=No OSPF neighbors found on ${device}
    FOR    ${neighbor}    ${state}    IN    &{neighbors}
        Should Contain    ${state}    Full
        ...    msg=OSPF neighbor ${neighbor} is not fully adjacent (state: ${state})
    END
```

---

## Pattern 3: Interface State Validation

**Use when:** Checking that specific interfaces are up/up or verifying error counters are not incrementing.

### Helper Function
```python
def get_interface_status(testbed_file, device_name, interface_name):
    """Get interface operational status and error counters."""
    device = None
    try:
        testbed = loader.load(testbed_file)
        device = testbed.devices[device_name]
        device.connect(log_stdout=False)

        command = 'show interface' if device.os == 'nxos' else 'show interfaces'
        output = device.parse(command)

        intf_data = output.get(interface_name, {})
        return {
            'enabled': intf_data.get('enabled', False),
            'oper_status': intf_data.get('oper_status', 'unknown'),
            'in_errors': intf_data.get('counters', {}).get('in_errors', 0),
            'out_errors': intf_data.get('counters', {}).get('out_errors', 0),
            'in_crc_errors': intf_data.get('counters', {}).get('in_crc_errors', 0),
        }
    except Exception as e:
        raise RuntimeError(f"Failed to get interface status on {device_name}: {e}") from e
    finally:
        if device and device.is_connected():
            device.disconnect()
```

### Test Cases
```robot
Interface Is Operationally Up
    [Documentation]    Validates that the specified interface is enabled and operationally up
    [Tags]    interface    critical
    ${status}=    Get Interface Status    ${testbed}    ${device}    ${interface}
    Should Be True    ${status}[enabled]    msg=${interface} is administratively disabled
    Should Be Equal    ${status}[oper_status]    up    msg=${interface} is operationally down

Interface Has No Errors
    [Documentation]    Validates that the specified interface has zero error counters
    [Tags]    interface    health    warning
    ${status}=    Get Interface Status    ${testbed}    ${device}    ${interface}
    Should Be Equal As Integers    ${status}[in_errors]    0
    ...    msg=${interface} has ${status}[in_errors] input errors
    Should Be Equal As Integers    ${status}[out_errors]    0
    ...    msg=${interface} has ${status}[out_errors] output errors
```

---

## Pattern 4: Failover / Convergence Testing

**Use when:** Testing that the network converges correctly after a link or device failure. This is a multi-step pattern: baseline → disrupt → verify impact → restore → verify recovery.

### Helper Function (Interface Toggle)
```python
def configure_interface_state(testbed_file, device_name, interface_name, shutdown=True):
    """Shutdown or restore an interface. Set shutdown=False to bring it back up."""
    device = None
    try:
        testbed = loader.load(testbed_file)
        device = testbed.devices[device_name]
        device.connect(log_stdout=False)

        action = 'shutdown' if shutdown else 'no shutdown'
        config_commands = [f'interface {interface_name}', action]

        # IOS-XR requires commit
        if device.os == 'iosxr':
            config_commands.append('commit')

        device.configure(config_commands)
    except Exception as e:
        raise RuntimeError(f"Failed to configure {interface_name} on {device_name}: {e}") from e
    finally:
        if device and device.is_connected():
            device.disconnect()
```

### Test Case
```robot
*** Settings ***
Resource    keywords.robot
Library     BuiltIn
Library     Collections

*** Test Cases ***
BGP Recovers After Link Failure
    [Documentation]    Shuts down a link, verifies BGP impact, restores, and confirms recovery
    [Tags]    bgp    failover    convergence    critical

    # Step 1: Baseline — confirm BGP is healthy
    ${baseline}=    Get BGP Neighbor States    ${testbed}    ${device}
    Should Not Be Empty    ${baseline}    msg=No BGP neighbors at baseline

    # Step 2: Disrupt — shutdown the interface
    Configure Interface State    ${testbed}    ${device}    ${interface}    shutdown=${True}
    Sleep    30s    reason=Wait for BGP hold timer expiry

    # Step 3: Verify impact — at least one neighbor should be affected
    ${during_failure}=    Get BGP Neighbor States    ${testbed}    ${device}
    Log    BGP states during failure: ${during_failure}

    # Step 4: Restore — bring the interface back up
    Configure Interface State    ${testbed}    ${device}    ${interface}    shutdown=${False}
    Sleep    60s    reason=Wait for BGP to re-establish

    # Step 5: Verify recovery — all neighbors should be back to established
    ${after_recovery}=    Get BGP Neighbor States    ${testbed}    ${device}
    FOR    ${neighbor}    ${state}    IN    &{after_recovery}
        Should Not Match Regexp    ${state}    ^(Idle|Active|Connect)$
        ...    msg=BGP neighbor ${neighbor} did not recover (state: ${state})
    END
```

---

## Pattern 5: Hardware Health Check

**Use when:** Monitoring CPU, memory, fans, power supplies, and temperature sensors.

### Helper Function
```python
def get_device_health(testbed_file, device_name):
    """Get CPU utilization and memory usage from a device."""
    device = None
    try:
        testbed = loader.load(testbed_file)
        device = testbed.devices[device_name]
        device.connect(log_stdout=False)

        health = {}

        # CPU
        cpu_output = device.parse('show processes cpu')
        health['cpu_five_min'] = cpu_output.get('five_min_cpu', 0)

        # Memory (platform-specific)
        if device.os == 'nxos':
            mem_output = device.parse('show system resources')
            total = mem_output.get('memory_usage_total', 1)
            used = mem_output.get('memory_usage_used', 0)
            health['memory_percent'] = round((used / total) * 100, 1)
        elif device.os == 'iosxe':
            mem_output = device.parse('show processes memory')
            pool = mem_output.get('processor_pool', {})
            total = pool.get('total', 1)
            used = pool.get('used', 0)
            health['memory_percent'] = round((used / total) * 100, 1)

        return health
    except Exception as e:
        raise RuntimeError(f"Failed to get health data from {device_name}: {e}") from e
    finally:
        if device and device.is_connected():
            device.disconnect()
```

### Test Cases
```robot
Device CPU Utilization Is Within Threshold
    [Documentation]    Validates 5-minute CPU average is below 80%
    [Tags]    health    cpu    warning
    ${health}=    Get Device Health    ${testbed}    ${device}
    Should Be True    ${health}[cpu_five_min] < 80
    ...    msg=CPU utilization is ${health}[cpu_five_min]% (threshold: 80%)

Device Memory Utilization Is Within Threshold
    [Documentation]    Validates memory usage is below 90%
    [Tags]    health    memory    warning
    ${health}=    Get Device Health    ${testbed}    ${device}
    Should Be True    ${health}[memory_percent] < 90
    ...    msg=Memory usage is ${health}[memory_percent]% (threshold: 90%)
```

---

## Pattern 6: Pre/Post Change Comparison

**Use when:** Capturing network state before a maintenance window, performing the change, then comparing to verify nothing unexpected changed.

### Helper Function
```python
import json

def capture_network_snapshot(testbed_file, device_name):
    """Capture a snapshot of key network state for comparison."""
    from genie.metaparser.util.exceptions import SchemaEmptyParserError

    device = None
    try:
        testbed = loader.load(testbed_file)
        device = testbed.devices[device_name]
        device.connect(log_stdout=False)

        snapshot = {}

        # Routing table
        route_cmd = 'show ip route vrf all' if device.os == 'nxos' else 'show ip route'
        try:
            routes = device.parse(route_cmd)
            route_count = sum(
                len(vrf_data.get('address_family', {}).get('ipv4', {}).get('routes', {}))
                for vrf_data in routes.get('vrf', {}).values()
            )
            snapshot['route_count'] = route_count
        except SchemaEmptyParserError:
            snapshot['route_count'] = 0

        # BGP neighbors
        bgp_cmd = 'show bgp summary' if device.os == 'iosxr' else 'show bgp all summary'
        try:
            bgp = device.parse(bgp_cmd)
            snapshot['bgp_neighbor_count'] = sum(
                len(vrf_data.get('neighbor', {}))
                for vrf_data in bgp.get('vrf', {}).values()
            )
        except SchemaEmptyParserError:
            snapshot['bgp_neighbor_count'] = 0

        # Interface count (up interfaces)
        intf_cmd = 'show interface' if device.os == 'nxos' else 'show interfaces'
        intfs = device.parse(intf_cmd)
        snapshot['up_interfaces'] = [
            name for name, data in intfs.items()
            if data.get('oper_status') == 'up'
        ]
        snapshot['up_interface_count'] = len(snapshot['up_interfaces'])

        return snapshot
    except Exception as e:
        raise RuntimeError(f"Failed to capture snapshot from {device_name}: {e}") from e
    finally:
        if device and device.is_connected():
            device.disconnect()


def compare_snapshots(before, after):
    """Compare two network snapshots and return differences."""
    differences = {}

    if before['route_count'] != after['route_count']:
        differences['route_count'] = {
            'before': before['route_count'],
            'after': after['route_count'],
            'delta': after['route_count'] - before['route_count'],
        }

    if before['bgp_neighbor_count'] != after['bgp_neighbor_count']:
        differences['bgp_neighbor_count'] = {
            'before': before['bgp_neighbor_count'],
            'after': after['bgp_neighbor_count'],
        }

    lost_interfaces = set(before['up_interfaces']) - set(after['up_interfaces'])
    if lost_interfaces:
        differences['lost_interfaces'] = list(lost_interfaces)

    return differences
```

### Test Case
```robot
Network State Is Unchanged After Maintenance
    [Documentation]    Captures state before/after a change and validates no unexpected differences
    [Tags]    maintenance    pre-post    critical

    # Capture baseline
    ${before}=    Capture Network Snapshot    ${testbed}    ${device}
    Log    Pre-change snapshot: ${before}

    # === PERFORM CHANGE HERE ===
    # (insert maintenance action keywords)

    # Capture post-change state
    ${after}=    Capture Network Snapshot    ${testbed}    ${device}
    Log    Post-change snapshot: ${after}

    # Compare
    ${differences}=    Compare Snapshots    ${before}    ${after}
    Should Be Empty    ${differences}
    ...    msg=Unexpected changes detected: ${differences}
```

---

## Pattern 7: RESTCONF API Validation

**Use when:** Validating device state via RESTCONF/REST API, especially when CLI parsers are unavailable or when testing API-based automation workflows.

### Helper Function
```python
import requests
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

def get_interfaces_via_restconf(testbed_file, device_name):
    """Get interface operational data via RESTCONF API."""
    device = None
    try:
        testbed = loader.load(testbed_file)
        device = testbed.devices[device_name]
        device.connect(alias='rest', via='rest', log_stdout=False)

        response = device.rest.get(
            '/restconf/data/ietf-interfaces:interfaces'
        )
        data = response.json()

        interfaces = {}
        for intf in data.get('ietf-interfaces:interfaces', {}).get('interface', []):
            interfaces[intf['name']] = {
                'enabled': intf.get('enabled', False),
                'type': intf.get('type', 'unknown'),
            }
        return interfaces
    except Exception as e:
        raise RuntimeError(f"Failed RESTCONF query on {device_name}: {e}") from e
    finally:
        if device and device.is_connected(alias='rest'):
            device.disconnect_from('rest')
```

### Test Case
```robot
All Interfaces Are Enabled Via RESTCONF
    [Documentation]    Validates interface enabled state using RESTCONF API
    [Tags]    restconf    interface    api    compliance
    ${interfaces}=    Get Interfaces Via RESTCONF    ${testbed}    ${device}
    Should Not Be Empty    ${interfaces}    msg=No interfaces returned from RESTCONF on ${device}
    FOR    ${name}    ${data}    IN    &{interfaces}
        Should Be True    ${data}[enabled]
        ...    msg=Interface ${name} is disabled on ${device}
    END
```

---

## Pattern 8: NETCONF Configuration Validation

**Use when:** Comparing running configuration against intended state via NETCONF, or validating configuration compliance using structured YANG data.

### Helper Function
```python
def get_bgp_config_netconf(testbed_file, device_name):
    """Get BGP configuration via NETCONF and return structured neighbor data."""
    device = None
    try:
        testbed = loader.load(testbed_file)
        device = testbed.devices[device_name]
        device.connect(alias='netconf', via='netconf', log_stdout=False)

        # Use Genie parser over NETCONF connection
        bgp_config = device.parse('show bgp all summary', connection_alias='netconf')
        return bgp_config
    except Exception as e:
        raise RuntimeError(f"Failed NETCONF query on {device_name}: {e}") from e
    finally:
        if device and device.is_connected(alias='netconf'):
            device.disconnect_from('netconf')
```

### Test Case
```robot
BGP Configuration Matches Intent Via NETCONF
    [Documentation]    Validates BGP neighbor configuration via NETCONF against expected neighbors
    [Tags]    netconf    bgp    api    compliance
    ${bgp_data}=    Get BGP Config NETCONF    ${testbed}    ${device}
    Should Not Be Empty    ${bgp_data}    msg=No BGP data returned via NETCONF on ${device}
    # Verify expected neighbors exist
    FOR    ${expected_neighbor}    IN    @{expected_bgp_neighbors}
        Dictionary Should Contain Key    ${bgp_data}[vrf][default][neighbor]    ${expected_neighbor}
        ...    msg=Expected BGP neighbor ${expected_neighbor} not found in config
    END
```
