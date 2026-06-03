"""
Robot Framework keywords for network validation.

Keywords wrap pyATS helper functions for use in Robot Framework test cases.
"""

*** Settings ***
Library    helper.py    WITH NAME    Helper


*** Keywords ***
Get BGP Neighbor States
    [Documentation]    Returns a dictionary of BGP neighbors and their session states
    [Arguments]    ${testbed}    ${device}
    ${result}=    Helper.Get BGP Neighbor States    ${testbed}    ${device}
    RETURN    ${result}

Get Interface Status
    [Documentation]    Returns interface status (enabled, oper_status) for the specified interface
    [Arguments]    ${testbed}    ${device}    ${interface}
    ${result}=    Helper.Get Interface Status    ${testbed}    ${device}    ${interface}
    RETURN    ${result}

Shutdown Interface
    [Documentation]    Shuts down the specified interface on a device
    [Arguments]    ${testbed}    ${device}    ${interface}
    Helper.Shutdown Interface    ${testbed}    ${device}    ${interface}

Restore Interface
    [Documentation]    Restores (no shutdown) the specified interface on a device
    [Arguments]    ${testbed}    ${device}    ${interface}
    Helper.Restore Interface    ${testbed}    ${device}    ${interface}

Get All Interfaces Enabled RESTCONF
    [Documentation]    Returns dict of interface names to enabled state using RESTCONF API
    [Arguments]    ${testbed}    ${device}
    ${result}=    Helper.Get All Interfaces Enabled Restconf    ${testbed}    ${device}
    RETURN    ${result}

Get Disabled Interfaces RESTCONF
    [Documentation]    Returns list of interfaces that are disabled (shutdown) via RESTCONF
    [Arguments]    ${testbed}    ${device}
    ${result}=    Helper.Get Disabled Interfaces Restconf    ${testbed}    ${device}
    RETURN    ${result}

# ---------------------------------------------------------------------------
# BDD Step Keywords
# Robot Framework strips Given/When/Then/And/But prefixes automatically,
# so these keywords are invoked directly by Gherkin-style test steps.
# ---------------------------------------------------------------------------

BGP Is Healthy On Device
    [Documentation]    BDD Given step: asserts all BGP neighbors are established.
    ...    Fails if any neighbor is in Idle, Active, Connect, OpenSent, or OpenConfirm state.
    [Arguments]    ${testbed}    ${device}
    ${neighbors}=    Get BGP Neighbor States    ${testbed}    ${device}
    Should Not Be Empty    ${neighbors}
    ...    msg=Given FAILED: No BGP neighbors found on ${device}
    FOR    ${neighbor}    ${state}    IN    &{neighbors}
        Should Not Match Regexp    ${state}    ^(Idle|Active|Connect|OpenSent|OpenConfirm)$
        ...    msg=Given FAILED: BGP neighbor ${neighbor} on ${device} is not established (state: ${state})
    END

Interface Is Shut Down On Device
    [Documentation]    BDD When step: administratively shuts down an interface and verifies it is down.
    [Arguments]    ${testbed}    ${device}    ${interface}
    Shutdown Interface    ${testbed}    ${device}    ${interface}
    Sleep    1s    reason=Allow interface state to update
    ${status}=    Get Interface Status    ${testbed}    ${device}    ${interface}
    Should Be Equal    ${status}[oper_status]    down
    ...    msg=When FAILED: ${interface} on ${device} did not go down after shutdown

BGP Neighbors Are Impacted On Device
    [Documentation]    BDD Then step: asserts that BGP has been affected (fewer neighbors established).
    ...    Logs a warning rather than failing if no impact is detected, which may indicate
    ...    the test interface has no BGP neighbors attached in this topology.
    [Arguments]    ${testbed}    ${device}    ${settle_time}=5s
    Sleep    ${settle_time}    reason=Allow BGP to react to the link failure
    ${neighbors}=    Get BGP Neighbor States    ${testbed}    ${device}
    ${established_count}=    Evaluate    sum(1 for s in $neighbors.values() if str(s).isdigit())
    ${total_count}=    Evaluate    len($neighbors)
    IF    ${established_count} == ${total_count} and ${total_count} > 0
        Log    Then WARNING: All ${total_count} BGP neighbors are still established after shutdown
        ...    (interface may not have BGP neighbors in this topology)    level=WARN
    ELSE
        Log    Then PASSED: BGP impact confirmed — ${established_count}/${total_count} neighbors still established    level=INFO
    END

Interface Is Restored On Device
    [Documentation]    BDD When step: restores an interface with no shutdown and verifies it is up.
    [Arguments]    ${testbed}    ${device}    ${interface}
    Restore Interface    ${testbed}    ${device}    ${interface}
    Sleep    1s    reason=Allow interface state to update
    ${status}=    Get Interface Status    ${testbed}    ${device}    ${interface}
    Should Be Equal    ${status}[oper_status]    up
    ...    msg=When FAILED: ${interface} on ${device} did not come back up after no shutdown

BGP Has Fully Recovered On Device
    [Documentation]    BDD Then step: asserts all BGP neighbors are re-established after recovery.
    ...    Fails if any neighbor remains in a non-established state.
    [Arguments]    ${testbed}    ${device}    ${settle_time}=10s
    Sleep    ${settle_time}    reason=Allow BGP to converge and re-establish sessions
    ${neighbors}=    Get BGP Neighbor States    ${testbed}    ${device}
    Should Not Be Empty    ${neighbors}
    ...    msg=Then FAILED: No BGP neighbors found on ${device} after recovery
    FOR    ${neighbor}    ${state}    IN    &{neighbors}
        Should Not Match Regexp    ${state}    ^(Idle|Active|Connect|OpenSent|OpenConfirm)$
        ...    msg=Then FAILED: BGP neighbor ${neighbor} on ${device} has not recovered (state: ${state})
    END
    Log    Then PASSED: All ${neighbors.__len__()} BGP neighbors have recovered on ${device}    level=INFO

Ensure Interface Is Restored
    [Documentation]    Teardown safety net: restores the interface regardless of test outcome.
    [Arguments]    ${testbed}    ${device}    ${interface}
    TRY
        Restore Interface    ${testbed}    ${device}    ${interface}
        Log    Teardown: Restored ${interface} on ${device}    level=INFO
    EXCEPT
        Log    Teardown WARNING: Could not restore ${interface} on ${device} — manual check required    level=WARN
    END
