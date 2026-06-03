---
description: "Use when designing network test suites, planning test cases, choosing assertions, or structuring Robot Framework test files for network automation. Covers test naming, isolation, ordering, and failure diagnostics."
---

# Network Test Design Standards

These guidelines apply when designing and structuring network automation test suites. They ensure tests are maintainable, debuggable, and provide clear signal when failures occur.

## Test Naming

Use descriptive names that state the expected outcome, not the action:

```robot
# GOOD — states the expected outcome
All BGP Neighbors Are Established on Spine-1
Device CPU Utilization Is Below 80 Percent
OSPF Adjacencies Recover After Link Restoration

# BAD — describes the action, not the expected result
Check BGP
Run CPU Test
Test OSPF
```

## Test Tagging

Every test case should include `[Tags]` for filtering and reporting:

| Tag Category | Examples | Purpose |
|-------------|----------|---------|
| Protocol | `bgp`, `ospf`, `isis`, `eigrp` | Filter by routing protocol |
| Severity | `critical`, `warning`, `informational` | Prioritize failures |
| Category | `routing`, `switching`, `health`, `compliance` | Group by domain |
| Platform | `nxos`, `iosxe`, `iosxr` | Filter by target platform |
| Type | `failover`, `convergence`, `pre-post`, `smoke` | Filter by test type |

```robot
Validate BGP Health on Core Routers
    [Tags]    bgp    critical    routing    nxos    smoke
```

## Test Isolation

Each test must be independently executable. Do not depend on another test running first.

- Each test connects to and disconnects from devices independently
- Destructive tests (interface shutdown, BGP clear) must include `[Teardown]` to restore state
- Never rely on test execution order — tests may run in parallel or be filtered

```robot
BGP Recovers After Interface Shutdown
    [Documentation]    Tests BGP convergence after a link failure
    [Tags]    bgp    failover    critical
    [Teardown]    Restore Interface    ${testbed}    ${device}    ${interface}
    # Test steps here...
```

## Assertion Patterns

### Use parsed data, not string matching

```robot
# GOOD — assertion on structured data
${neighbors}=    Get BGP Neighbor States    ${testbed}    ${device}
Should Not Match Regexp    ${neighbors}[10.1.1.1]    ^(Idle|Active)$

# BAD — fragile string matching on raw CLI output
${output}=    Execute Command    show bgp summary
Should Contain    ${output}    Established
```

### Choose the right assertion

| Assertion | Use When |
|-----------|----------|
| `Should Be Equal` | Exact value match (version string, specific state) |
| `Should Be True` | Numeric comparison (`${cpu} < 80`) |
| `Should Not Be Empty` | Verifying data exists (neighbors, routes) |
| `Should Not Match Regexp` | Negative pattern match (not in bad state) |
| `Should Contain` | Substring match (only when no parser available) |

### Always include failure messages

Every assertion should include a `msg=` parameter that describes what went wrong and includes the actual value:

```robot
Should Be True    ${health}[cpu_five_min] < 80
...    msg=CPU utilization is ${health}[cpu_five_min]% on ${device} (threshold: 80%)
```

## Test Suite Organization

Structure test files by purpose:

```
tests/
├── smoke_tests.robot          # Quick validation (version, reachability)
├── routing_tests.robot        # BGP, OSPF, ISIS neighbor validation
├── interface_tests.robot      # Interface state and error checks
├── health_tests.robot         # CPU, memory, environment
├── failover_tests.robot       # Convergence and recovery scenarios
└── compliance_tests.robot     # Policy and configuration compliance
```

## Failure Diagnostics

When a test fails, the failure message should contain enough information to diagnose the issue without re-running the test:

1. **What was expected** — the target state or threshold
2. **What was observed** — the actual value from the device
3. **Where it happened** — which device and which resource (interface, neighbor, etc.)

```robot
# Good failure message:
# "BGP neighbor 10.1.1.1 is not established (state: Active) on Spine-1"

# Bad failure message:
# "Assertion failed"
```

## Destructive Test Ordering

When a test suite contains both read-only and destructive tests:

1. Run all read-only validation tests first (version, health, neighbor state)
2. Run destructive tests last (failover, convergence, clear operations)
3. Use `[Teardown]` on every destructive test to restore original state
4. Consider a suite-level `Suite Teardown` that performs a comprehensive restoration

```robot
*** Settings ***
Resource    keywords.robot
Suite Teardown    Restore All Interfaces    ${testbed}    ${device}
```

## BDD-Style Test Structure

Robot Framework supports Behavior Driven Development (BDD) syntax with Given/When/Then keywords. Use this style when tests describe network behavior scenarios that non-developers should understand.

### BDD Keyword Naming

Prefix keywords with `Given`, `When`, or `Then` to express intent:

```robot
*** Keywords ***
Given BGP Is Healthy On ${device}
    [Documentation]    Precondition: verify all BGP neighbors are established
    ${neighbors}=    Get BGP Neighbor States    ${testbed}    ${device}
    Should Not Be Empty    ${neighbors}    msg=No BGP neighbors found on ${device}
    FOR    ${neighbor}    ${state}    IN    &{neighbors}
        Should Not Match Regexp    ${state}    ^(Idle|Active|Connect)$
        ...    msg=Precondition failed: BGP neighbor ${neighbor} not established (${state})
    END

When Interface ${interface} Is Shut Down On ${device}
    [Documentation]    Action: administratively shut down an interface
    Configure Interface State    ${testbed}    ${device}    ${interface}    shutdown=${True}
    Sleep    30s    reason=Wait for protocol convergence

Then BGP Should Recover On ${device}
    [Documentation]    Postcondition: all BGP neighbors return to established state
    ${neighbors}=    Get BGP Neighbor States    ${testbed}    ${device}
    FOR    ${neighbor}    ${state}    IN    &{neighbors}
        Should Not Match Regexp    ${state}    ^(Idle|Active|Connect)$
        ...    msg=BGP neighbor ${neighbor} did not recover (state: ${state})
    END

When Interface ${interface} Is Restored On ${device}
    [Documentation]    Action: bring an interface back up
    Configure Interface State    ${testbed}    ${device}    ${interface}    shutdown=${False}
    Sleep    60s    reason=Wait for BGP to re-establish
```

### BDD Test Case

```robot
*** Test Cases ***
BGP Recovers After Link Failure On Spine-1
    [Documentation]    Scenario: Network reconverges after a link failure
    [Tags]    bgp    failover    convergence    critical    bdd
    [Teardown]    When Interface Ethernet1/1 Is Restored On Spine-1
    Given BGP Is Healthy On Spine-1
    When Interface Ethernet1/1 Is Shut Down On Spine-1
    And Interface Ethernet1/1 Is Restored On Spine-1
    Then BGP Should Recover On Spine-1
```

### When to Use BDD vs Standard Style

| Style | Use When |
|-------|----------|
| **BDD (Given/When/Then)** | Multi-step scenarios, failover tests, change validation — tests that tell a story |
| **Standard** | Simple state checks, health validations, compliance — direct assertion tests |

Do not force BDD syntax on simple validation tests. "Device Is Running Expected Version" does not need Given/When/Then.
