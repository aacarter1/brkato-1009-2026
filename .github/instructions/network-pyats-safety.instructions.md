---
applyTo: "**/*.py,**/*.robot"
description: "pyATS and network automation safety guardrails. Enforces secure connection handling, credential safety, and robust device interaction patterns."
---

# pyATS Network Automation Safety Guidelines

These rules apply automatically to all Python and Robot Framework files in this project. They enforce safe patterns for network device automation using pyATS/Genie.

## Connection Handling

### Always disconnect in a finally block

Every function that connects to a device MUST disconnect in a `finally` block. Leaked connections tie up VTY lines and can lock operators out of devices.

```python
# CORRECT
def my_function(testbed_file, device_name):
    device = None
    try:
        testbed = loader.load(testbed_file)
        device = testbed.devices[device_name]
        device.connect(log_stdout=False)
        # ... do work ...
    finally:
        if device and device.is_connected():
            device.disconnect()

# WRONG — connection leaks on any exception
def my_function(testbed_file, device_name):
    testbed = loader.load(testbed_file)
    device = testbed.devices[device_name]
    device.connect()
    output = device.parse('show version')
    device.disconnect()
    return output
```

### Suppress verbose connection output

Always pass `log_stdout=False` to `device.connect()` to prevent pyATS connection banners from flooding test output.

### Handle connection timeouts

Network devices may be unreachable. Always let connection errors propagate with a meaningful message:

```python
except ConnectionError as e:
    raise RuntimeError(f"Cannot reach {device_name} — check reachability and credentials: {e}") from e
```

## Credential Safety

### Never hardcode credentials

Testbed files MUST use `%ENV{}` syntax for credentials. Never write passwords directly in YAML or Python files.

```yaml
# CORRECT
credentials:
  default:
    username: "%ENV{PYATS_USERNAME}"
    password: "%ENV{PYATS_PASSWORD}"

# WRONG — exposed credentials
credentials:
  default:
    username: admin
    password: cisco123
```

### Never log or print credentials

Do not include credentials in log messages, error messages, or print statements. If logging connection details, redact sensitive fields.

## Parsed Output Over Raw Text

### Prefer device.parse() over device.execute()

Always use Genie parsers (`device.parse()`) when available. Parsed output returns structured dictionaries that are reliable across software versions. Raw text output (`device.execute()`) is fragile and breaks when output formatting changes.

```python
# CORRECT — structured, reliable
output = device.parse('show bgp all summary')
state = output['vrf']['default']['neighbor']['10.1.1.1']['state_pfxrcd']

# WRONG — fragile, breaks with formatting changes
output = device.execute('show bgp all summary')
if 'Established' in output:
    pass
```

### Handle empty parser output

When a feature is not configured, Genie parsers raise `SchemaEmptyParserError`. Always handle this:

```python
from genie.metaparser.util.exceptions import SchemaEmptyParserError

try:
    output = device.parse('show bgp all summary')
except SchemaEmptyParserError:
    return {}  # Feature not configured — return empty
```

## Configuration Safety

### Never run destructive commands without explicit intent

Functions that modify device configuration (shutdown, clear, reload) must:
1. Have the destructive action clearly named in the function name
2. Accept the target (interface, protocol, etc.) as an explicit parameter
3. Never use wildcards unless the user specifically requests them

### IOS-XR requires commit

When configuring IOS-XR devices, always include `commit` after configuration changes. Without it, changes are staged but not applied.

```python
if device.os == 'iosxr':
    config_commands.append('commit')
device.configure(config_commands)
```

## Robot Framework Patterns

### Use RETURN, not [Return]

Use the modern `RETURN` keyword (Robot Framework 5+), not the deprecated `[Return]` setting.

### Test isolation

Each test case should be independent. Do not rely on a previous test's side effects. If a test shuts down an interface, it must restore it in a teardown:

```robot
Test Shut Interface Impact
    [Setup]    Log    Beginning interface failover test
    [Teardown]    Restore Interface    ${testbed}    ${device}    ${interface}
    Shutdown Interface    ${testbed}    ${device}    ${interface}
    # ... assertions ...
```
