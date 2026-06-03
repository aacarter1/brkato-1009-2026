---
name: network-testing
description: "Generate network automation tests using pyATS/Genie and Robot Framework. Use when: creating network test cases, writing pyATS helper functions, building Robot Framework keywords for network validation, testing BGP/OSPF/ISIS routing protocols, validating device health via CLI/NETCONF/RESTCONF, interface states, or software versions across NX-OS, IOS-XE, and IOS-XR platforms."
argument-hint: "Describe the network test you want to create (e.g., 'BGP neighbor health check for all spine switches')"
---

# Network Testing Skill

Generate production-quality network automation tests using Cisco pyATS/Genie and Robot Framework. This skill encodes network test engineering expertise for NX-OS, IOS-XE, and IOS-XR platforms.

## When to Use

- Creating new network test cases (routing, switching, hardware health, compliance)
- Writing pyATS helper functions that connect to devices and validate state
- Building Robot Framework keywords and test suites for network validation
- Testing pre/post-change network state (maintenance windows, upgrades, migrations)
- Validating routing protocol health (BGP, OSPF, ISIS, EIGRP)
- Checking interface states, error counters, and throughput
- Verifying device software versions, hardware inventory, or environment sensors
- Building failover and convergence test scenarios
- Validating device state via NETCONF or RESTCONF APIs
- Testing API-based automation workflows alongside CLI-based tests

## Procedure

Follow these steps when generating network tests.

### Step 1: Read the Testbed

Before generating any test code, read the user's `testbed.yaml` file to understand:
- Which devices are defined and their `os` field (`nxos`, `iosxe`, `iosxr`)
- Device names and aliases (used in test naming and connection)
- Connection methods (cli, netconf, restconf) — determines which interface to use
- Whether credentials use `%ENV{}` tokens or are inline

If no testbed exists, generate one using the [testbed template](./assets/testbed-template.yaml).

### Step 2: Identify the Platform and Connection Method

The `os` field in the testbed determines which commands and parser output paths to use. The `connections` block determines available interfaces. Consult the [platform commands reference](./references/platform-commands.md) for:
- The correct show commands per platform (CLI)
- NETCONF and RESTCONF connection patterns and YANG paths
- Parser output key paths (these differ between NX-OS, IOS-XE, and IOS-XR)
- Configuration syntax for destructive operations (shutdown, clear, etc.)
- The connection method selection guide (CLI vs NETCONF vs RESTCONF)

**Critical**: Never assume parser output paths are the same across platforms. Always check the reference.

### Step 3: Select a Test Pattern

Consult the [test patterns reference](./references/test-patterns.md) to select the appropriate pattern:
- **State validation** — verify current state matches expected (version, BGP state, interface status)
- **Failover/convergence** — disable component → verify impact → restore → verify recovery
- **Pre/post comparison** — capture baseline → perform change → compare against baseline
- **Health check** — verify CPU, memory, environment sensors within thresholds
- **API validation** — verify device state via RESTCONF or NETCONF (use when testing API workflows or when CLI parsers are unavailable)

### Step 4: Generate the Helper Function (Python)

Create a Python helper function in `helper.py` following this structure:

```python
from pyats.topology import loader
from genie.libs.parser.utils.common import ParserNotFound

def <function_name>(testbed_file, device_name, **kwargs):
    """
    <Clear description of what this function validates>
    
    Args:
        testbed_file: Path to pyATS testbed YAML file
        device_name: Name of the device in the testbed
        **kwargs: Additional parameters (interface name, VRF, expected values, etc.)
    
    Returns:
        Parsed output dictionary or specific extracted values
    """
    device = None
    try:
        testbed = loader.load(testbed_file)
        device = testbed.devices[device_name]
        device.connect(log_stdout=False, learn_hostname=True)

        output = None
        for command in ['<command-1>', '<command-2>']:
            try:
                output = device.parse(command)
                break
            except ParserNotFound:
                continue

        # Last resort only when parser coverage is unavailable.
        if output is None:
            raw_output = device.execute('<fallback-command>')
            result = <extract_from_text>(raw_output)
            return result
        
        # Extract the specific field(s) needed
        # Use platform-appropriate key paths from the reference
        result = output['<key>']['<subkey>']
        
        return result
    except Exception as e:
        raise RuntimeError(f"Failed to <action> on {device_name}: {e}") from e
    finally:
        if device and device.is_connected():
            device.disconnect()
```

**Rules for helper functions:**
- Always use `try/finally` to ensure device disconnection
- Always use `device.parse()` first; use `device.execute()` only as a last-resort fallback when parser coverage is unavailable
- Pass `log_stdout=False, learn_hostname=True` to `device.connect()` to suppress verbose output and tolerate prompt/testbed hostname mismatches
- Return structured data (dicts, specific values), not raw CLI text
- Include meaningful error messages with the device name
- Accept `testbed_file` and `device_name` as first two parameters (consistent API)

### Step 5: Generate the Robot Framework Keyword

Create a keyword in `keywords.robot` that wraps the helper function:

```robot
*** Settings ***
Library    helper.py

*** Keywords ***
<Keyword Name>
    [Documentation]    <What this keyword does>
    [Arguments]    ${testbed}    ${device}    @{extra_args}
    ${result}=    <Python Function Name>    ${testbed}    ${device}    @{extra_args}
    RETURN    ${result}
```

**Rules for keywords:**
- Keyword names use Title Case with spaces (Robot Framework convention)
- Always include `[Documentation]`
- Pass through testbed and device as the first two arguments
- Use `RETURN` (not `[Return]`) for Robot Framework 5+ compatibility

### Step 6: Generate the Test Case

Create test cases in a `.robot` file:

```robot
*** Settings ***
Resource    keywords.robot

*** Test Cases ***
<Descriptive Test Name>
    [Documentation]    <What this test validates and why it matters>
    [Tags]    <platform>    <protocol>    <severity>
    ${result}=    <Keyword Name>    ${testbed}    ${device}
    <Assertion>    ${result}    <expected_value>
```

**Rules for test cases:**
- Test names describe the expected outcome: "BGP Neighbors Are Established on Spine-1"
- Always include `[Tags]` for filtering: platform (nxos/iosxe/iosxr), protocol (bgp/ospf), severity (critical/warning)
- Use appropriate assertions:
  - `Should Be Equal` — exact match (version strings, states)
  - `Should Contain` — substring match (only when parsed output unavailable)
  - `Should Not Contain` — negative validation
  - `Should Be True` — numeric comparisons (`${cpu} < 80`)
  - `Should Not Be Empty` — existence checks
- Prefer assertions on parsed structured data over raw string matching

### Step 7: Review Against Instructions

Before finalizing, verify the generated code against:
- The [pyATS safety instruction](../../instructions/network-pyats-safety.instructions.md) — connection handling, credential safety
- The [test design instruction](../../instructions/network-test-design.instructions.md) — naming, isolation, assertion patterns

## Code Generation Examples

### Example: BGP Neighbor Health Check

**User request**: "Check that all BGP neighbors are established on my spine switches"

**Generated helper.py function:**
```python
def get_bgp_neighbor_states(testbed_file, device_name):
    """Check BGP neighbor states and return dict of neighbor: state pairs."""
    device = None
    try:
        testbed = loader.load(testbed_file)
        device = testbed.devices[device_name]
        device.connect(log_stdout=False, learn_hostname=True)

        commands = [
            'show bgp all summary',
            'show bgp ipv4 unicast summary',
            'show bgp vrf all all summary',
        ]
        bgp_output = None
        for command in commands:
            try:
                bgp_output = device.parse(command)
                break
            except ParserNotFound:
                continue

        if bgp_output is None:
            raw_output = device.execute(commands[0])
            return extract_neighbors_from_text(raw_output)
        
        neighbor_states = {}
        for vrf_data in bgp_output.get('vrf', {}).values():
            for neighbor, details in vrf_data.get('neighbor', {}).items():
                state = details.get('state_pfxrcd', '')
                neighbor_states[neighbor] = state
        
        return neighbor_states
    except Exception as e:
        raise RuntimeError(f"Failed to get BGP neighbors on {device_name}: {e}") from e
    finally:
        if device and device.is_connected():
            device.disconnect()
```

**Generated test case:**
```robot
*** Test Cases ***
All BGP Neighbors Are Established on Spine-1
    [Documentation]    Validates that no BGP neighbors are in Idle or Active state
    [Tags]    bgp    critical    spine
    ${neighbors}=    Get BGP Neighbor States    ${testbed}    Spine-1
    FOR    ${neighbor}    ${state}    IN    &{neighbors}
        Should Not Match Regexp    ${state}    ^(Idle|Active|Connect)$
        ...    msg=BGP neighbor ${neighbor} is in unexpected state: ${state}
    END
```

## Important Notes

- **Parser availability**: Not all commands have Genie parsers on all platforms/releases. Use `device.parse('show ...')` first, handle `SchemaEmptyParserError` when no data is returned, handle `ParserNotFound` for coverage gaps, and fall back to controlled text extraction only when parser candidates are exhausted. Check the [pyATS parser list](https://pubhub.devnetcloud.com/media/genie-feature-browser/docs/#/parsers) for availability.
- **Platform differences**: Always reference the [platform commands](./references/platform-commands.md) doc. The same logical check (e.g., "is BGP healthy?") uses different commands and output structures per platform.
- **Testbed credentials**: Never generate testbed files with inline passwords. Always use `%ENV{PYATS_USERNAME}` and `%ENV{PYATS_PASSWORD}` syntax.
- **Connection methods**: Default to CLI (`device.parse()`) for show command validation. Use NETCONF when the testbed defines a `netconf` connection and the user requests structured YANG data. Use RESTCONF when testing REST API workflows. See the connection method selection guide in the platform commands reference.
- **CXTM execution**: The generated Robot Framework tests are designed to execute both locally (`robot <file>.robot`) and within Cisco's CX Test Automation Manager (CXTM) for centralized test orchestration. No CXTM-specific code is needed — CXTM natively runs Robot Framework suites.
