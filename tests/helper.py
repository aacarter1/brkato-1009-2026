"""
pyATS helper functions for network validation.

Provides reusable, device-agnostic functions to validate network state across
NX-OS, IOS-XE, and IOS-XR platforms.
"""

import re

from pyats.topology import loader
from genie.metaparser.util.exceptions import SchemaEmptyParserError
from genie.libs.parser.utils.common import ParserNotFound


def _extract_bgp_neighbors_from_text(output_text):
    """Extract neighbor -> state/prefix from raw BGP summary output."""
    neighbor_states = {}
    for line in output_text.splitlines():
        line = line.strip()
        if not line:
            continue

        parts = line.split()
        if not parts:
            continue

        # BGP summary neighbor rows start with an IP address.
        if re.match(r'^\d+\.\d+\.\d+\.\d+$', parts[0]):
            neighbor_ip = parts[0]
            state = parts[-1]
            neighbor_states[neighbor_ip] = state

    return neighbor_states


def _get_bgp_summary_commands(os_name):
    """Return parser/CLI command candidates per platform."""
    if os_name == 'iosxr':
        return ['show bgp summary']
    if os_name == 'nxos':
        return [
            'show bgp all summary',
            'show bgp ipv4 unicast summary',
            'show bgp vrf all all summary',
            'show bgp vrf all summary',
        ]
    return [
        'show bgp all summary',
        'show bgp ipv4 unicast summary',
    ]


def get_bgp_neighbor_states(testbed_file, device_name):
    """
    Get all BGP neighbor states from a device.

    Validates BGP neighbor session state by parsing 'show bgp all summary' (or
    'show bgp summary' on IOS-XR) and returning a dict mapping neighbor IPs to
    their session states.

    Args:
        testbed_file: Path to pyATS testbed YAML file
        device_name: Name of the device in the testbed

    Returns:
        Dictionary mapping neighbor IP addresses to their session states.
        Example: {'10.0.0.1': '10', '10.0.0.2': 'Idle'}
        - Numeric values (e.g., '10', '100') indicate established (prefix count)
        - Text values ('Idle', 'Active', 'Connect', etc.) indicate not established

    Raises:
        RuntimeError: If connection fails or parsing errors occur
    """
    device = None
    try:
        testbed = loader.load(testbed_file)
        device = testbed.devices[device_name]
        device.connect(log_stdout=False, learn_hostname=True)

        commands = _get_bgp_summary_commands(device.os)

        output = None
        last_parse_error = None
        for command in commands:
            try:
                output = device.parse(command)
                break
            except SchemaEmptyParserError:
                return {}
            except ParserNotFound as e:
                last_parse_error = e
                continue
            except Exception as e:
                last_parse_error = e
                continue

        neighbor_states = {}

        if output is not None:
            # Extract neighbors based on platform structure.
            if device.os == 'iosxr':
                # IOS-XR structure: instance -> default -> vrf -> neighbor
                for instance_data in output.get('instance', {}).values():
                    for vrf_data in instance_data.get('vrf', {}).values():
                        for neighbor_ip, details in vrf_data.get('neighbor', {}).items():
                            state = details.get('session_state', 'Unknown')
                            neighbor_states[neighbor_ip] = state
            else:
                # NX-OS and IOS-XE structure: vrf -> neighbor
                for vrf_data in output.get('vrf', {}).values():
                    for neighbor_ip, details in vrf_data.get('neighbor', {}).items():
                        state = details.get('state_pfxrcd', 'Unknown')
                        neighbor_states[neighbor_ip] = state

            return neighbor_states

        # Parser coverage can vary by platform/release; fall back to text parsing.
        last_execute_error = None
        for command in commands:
            try:
                raw_output = device.execute(command)
                neighbor_states = _extract_bgp_neighbors_from_text(raw_output)
                return neighbor_states
            except Exception as e:
                last_execute_error = e
                continue

        if last_execute_error:
            raise last_execute_error
        if last_parse_error:
            raise last_parse_error
        return {}

    except Exception as e:
        raise RuntimeError(f"Failed to get BGP neighbors on {device_name}: {e}") from e
    finally:
        if device and device.is_connected():
            device.disconnect()


def get_interface_status(testbed_file, device_name, interface_name):
    """
    Get the operational status of an interface.

    Queries the interface status via 'show interface' and returns whether
    the interface is enabled and operational.

    Args:
        testbed_file: Path to pyATS testbed YAML file
        device_name: Name of the device in the testbed
        interface_name: Interface name (e.g., 'Ethernet1/1')

    Returns:
        Dictionary with keys:
        - 'enabled': bool (administrative status)
        - 'oper_status': str ('up' or 'down')

    Raises:
        RuntimeError: If connection fails or interface is not found
    """
    device = None
    try:
        testbed = loader.load(testbed_file)
        device = testbed.devices[device_name]
        device.connect(log_stdout=False, learn_hostname=True)

        try:
            output = device.parse('show interface')
        except SchemaEmptyParserError:
            raise RuntimeError(f"No interface data returned from {device_name}")

        if interface_name not in output:
            raise RuntimeError(f"Interface {interface_name} not found on {device_name}")

        intf_data = output[interface_name]
        return {
            'enabled': intf_data.get('enabled', False),
            'oper_status': intf_data.get('oper_status', 'Unknown')
        }

    except Exception as e:
        raise RuntimeError(f"Failed to get interface status on {device_name}: {e}") from e
    finally:
        if device and device.is_connected():
            device.disconnect()


def shutdown_interface(testbed_file, device_name, interface_name):
    """
    Shut down an interface.

    Sends configuration commands to administratively disable the specified
    interface. This triggers link-down behavior for testing failover scenarios.

    Args:
        testbed_file: Path to pyATS testbed YAML file
        device_name: Name of the device in the testbed
        interface_name: Interface name (e.g., 'Ethernet1/1')

    Raises:
        RuntimeError: If configuration fails or device is unreachable
    """
    device = None
    try:
        testbed = loader.load(testbed_file)
        device = testbed.devices[device_name]
        device.connect(log_stdout=False, learn_hostname=True)

        # Platform-specific configuration sequence
        if device.os == 'iosxr':
            # IOS-XR requires explicit commit
            config_lines = [
                f'interface {interface_name}',
                'shutdown'
            ]
            device.configure(config_lines)
            device.execute('commit')
        else:
            # NX-OS and IOS-XE
            config_lines = [
                f'interface {interface_name}',
                'shutdown'
            ]
            device.configure(config_lines)

    except Exception as e:
        raise RuntimeError(f"Failed to shutdown {interface_name} on {device_name}: {e}") from e
    finally:
        if device and device.is_connected():
            device.disconnect()


def restore_interface(testbed_file, device_name, interface_name):
    """
    Restore (no shutdown) an interface.

    Sends configuration commands to administratively enable the specified
    interface. Used to restore connectivity after testing failover scenarios.

    Args:
        testbed_file: Path to pyATS testbed YAML file
        device_name: Name of the device in the testbed
        interface_name: Interface name (e.g., 'Ethernet1/1')

    Raises:
        RuntimeError: If configuration fails or device is unreachable
    """
    device = None
    try:
        testbed = loader.load(testbed_file)
        device = testbed.devices[device_name]
        device.connect(log_stdout=False, learn_hostname=True)

        # Platform-specific configuration sequence
        if device.os == 'iosxr':
            # IOS-XR requires explicit commit
            config_lines = [
                f'interface {interface_name}',
                'no shutdown'
            ]
            device.configure(config_lines)
            device.execute('commit')
        else:
            # NX-OS and IOS-XE
            config_lines = [
                f'interface {interface_name}',
                'no shutdown'
            ]
            device.configure(config_lines)

    except Exception as e:
        raise RuntimeError(f"Failed to restore {interface_name} on {device_name}: {e}") from e
    finally:
        if device and device.is_connected():
            device.disconnect()


def get_all_interfaces_enabled_restconf(testbed_file, device_name):
    """
    Get all interfaces and their enabled state using RESTCONF API.

    Queries the RESTCONF endpoint /ietf-interfaces:interfaces to retrieve
    interface configuration, including the enabled state for each interface.
    Uses standard IETF YANG models compatible with IOS-XE.

    Args:
        testbed_file: Path to pyATS testbed YAML file
        device_name: Name of the device in the testbed (must have REST connection)

    Returns:
        Dictionary mapping interface names to their enabled state (bool).
        Example: {'GigabitEthernet0/0/0': True, 'GigabitEthernet0/0/1': False}

    Raises:
        RuntimeError: If RESTCONF query fails or connection is unavailable
    """
    device = None
    try:
        testbed = loader.load(testbed_file)
        device = testbed.devices[device_name]
        device.connect(alias='rest', via='rest', log_stdout=False)

        # Query RESTCONF interfaces endpoint
        # Returns IETF ietf-interfaces:interfaces YANG model
        response = device.rest.get('/restconf/data/ietf-interfaces:interfaces')
        response.raise_for_status()
        data = response.json()

        interface_states = {}

        # Parse the YANG model structure
        # Structure: {"ietf-interfaces:interfaces": {"interface": [...]}}
        interfaces_container = data.get('ietf-interfaces:interfaces', {})
        interfaces_list = interfaces_container.get('interface', [])

        for interface in interfaces_list:
            name = interface.get('name')
            enabled = interface.get('enabled', False)
            if name:
                interface_states[name] = enabled

        return interface_states

    except Exception as e:
        raise RuntimeError(
            f"Failed to get interfaces via RESTCONF on {device_name}: {e}"
        ) from e
    finally:
        if device and device.is_connected(alias='rest'):
            device.disconnect_from('rest')


def get_disabled_interfaces_restconf(testbed_file, device_name):
    """
    Get list of disabled (shutdown) interfaces using RESTCONF.

    Queries all interfaces via RESTCONF and returns only those where
    enabled=False, indicating administratively disabled interfaces.

    Args:
        testbed_file: Path to pyATS testbed YAML file
        device_name: Name of the device in the testbed (must have REST connection)

    Returns:
        List of interface names that are disabled (enabled=False).
        Example: ['GigabitEthernet0/0/1', 'GigabitEthernet0/0/2']
        Empty list if all interfaces are enabled.

    Raises:
        RuntimeError: If RESTCONF query fails
    """
    try:
        all_interfaces = get_all_interfaces_enabled_restconf(testbed_file, device_name)
        disabled = [name for name, enabled in all_interfaces.items() if not enabled]
        return disabled
    except Exception as e:
        raise RuntimeError(f"Failed to get disabled interfaces on {device_name}: {e}") from e
