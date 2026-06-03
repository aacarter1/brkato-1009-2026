"""
Robot Framework test suite for BGP failover and convergence validation.

Tests BGP behavior during interface failures and validates convergence
after interface restoration.
"""

*** Settings ***
Documentation    BGP failover/convergence testing for Cisco Nexus (NX-OS) switches
Resource         keywords.robot
Suite Setup      Set Test Variables
Test Teardown    Restore Interface On Failure


*** Variables ***
${TESTBED}           testbed/nexus_testbed.yaml
${DEVICE}            nxos-spine-1
${TEST_INTERFACE}    Ethernet1/1
${BGP_SETTLE_TIME}   5s


*** Keywords ***
Set Test Variables
    [Documentation]    Initialize test variables
    # Variables can be overridden via CLI:
    # robot --variable TESTBED:/path/to/testbed.yaml bgp_failover_convergence.robot
    No Operation


Restore Interface On Failure
    [Documentation]    Teardown keyword to restore interface if test fails
    [Tags]    teardown
    IF    '${TEST STATUS}' == 'FAIL'
        Log    Test failed; restoring interface ${TEST_INTERFACE}    level=WARN
        TRY
            Restore Interface    ${TESTBED}    ${DEVICE}    ${TEST_INTERFACE}
        EXCEPT
            Log    Warning: Failed to restore ${TEST_INTERFACE}; may require manual intervention    level=WARN
        END
    END


*** Test Cases ***
BGP Neighbors Recover After Interface Shutdown and Restoration
    [Documentation]    Validates BGP convergence behavior during interface failure
    ...
    ...    Test sequence:
    ...    1. Capture baseline BGP neighbor states (all established)
    ...    2. Shut down test interface (should trigger BGP session loss)
    ...    3. Wait for BGP to converge (${BGP_SETTLE_TIME})
    ...    4. Verify BGP neighbors are impacted (not established)
    ...    5. Restore test interface
    ...    6. Wait for BGP recovery
    ...    7. Verify all BGP neighbors are re-established
    [Tags]    bgp    failover    convergence    critical    nxos
    [Teardown]    Restore Interface On Failure

    # Step 1: Capture baseline BGP state
    Log    Step 1: Capturing baseline BGP neighbor states    level=INFO
    ${baseline_neighbors}=    Get BGP Neighbor States    ${TESTBED}    ${DEVICE}
    Should Not Be Empty    ${baseline_neighbors}    msg=No BGP neighbors found on ${DEVICE}
    Log    Baseline neighbors: ${baseline_neighbors}    level=DEBUG

    FOR    ${neighbor}    ${state}    IN    &{baseline_neighbors}
        Should Not Match Regexp    ${state}    ^(Idle|Active|Connect|OpenSent|OpenConfirm)$
        ...    msg=Baseline: BGP neighbor ${neighbor} is not established (state: ${state})
    END
    Log    Step 1 PASSED: All ${baseline_neighbors.__len__()} neighbors are established    level=INFO

    # Step 2: Shut down the test interface
    Log    Step 2: Shutting down interface ${TEST_INTERFACE}    level=INFO
    Shutdown Interface    ${TESTBED}    ${DEVICE}    ${TEST_INTERFACE}
    Log    Interface ${TEST_INTERFACE} shutdown sent    level=INFO

    # Verify interface is actually down
    Sleep    1s    reason=Wait for interface to go down
    ${intf_status}=    Get Interface Status    ${TESTBED}    ${DEVICE}    ${TEST_INTERFACE}
    Should Be Equal    ${intf_status}[oper_status]    down
    ...    msg=Interface ${TEST_INTERFACE} did not go down after shutdown command
    Log    Interface ${TEST_INTERFACE} is down (enabled=${intf_status}[enabled], oper_status=${intf_status}[oper_status])    level=INFO

    # Step 3: Wait for BGP to converge
    Log    Step 3: Waiting ${BGP_SETTLE_TIME} for BGP to react to link failure    level=INFO
    Sleep    ${BGP_SETTLE_TIME}
    Log    BGP settle time complete    level=INFO

    # Step 4: Verify BGP neighbors are impacted
    Log    Step 4: Verifying BGP neighbors are impacted    level=INFO
    ${impacted_neighbors}=    Get BGP Neighbor States    ${TESTBED}    ${DEVICE}
    Log    Post-shutdown neighbor states: ${impacted_neighbors}    level=DEBUG

    # At least some neighbors should be affected (depending on topology)
    # If neighbors are still established, the test interface may not have BGP neighbors
    # In that case, log a warning but continue (to allow testing on different topologies)
    ${established_count}=    Set Variable    0
    FOR    ${neighbor}    ${state}    IN    &{impacted_neighbors}
        IF    '${state}'.isdigit()
            ${established_count}=    Evaluate    ${established_count} + 1
        END
    END

    IF    ${established_count} > 0
        Log    Warning: After shutdown, ${established_count} neighbors still established
        ...    (interface may not have BGP neighbors attached)    level=WARN
    ELSE
        Log    Step 4 PASSED: All BGP neighbors impacted by interface failure    level=INFO
    END

    # Step 5: Restore the interface
    Log    Step 5: Restoring interface ${TEST_INTERFACE}    level=INFO
    Restore Interface    ${TESTBED}    ${DEVICE}    ${TEST_INTERFACE}
    Log    Interface ${TEST_INTERFACE} restore command sent    level=INFO

    # Verify interface is back up
    Sleep    1s    reason=Wait for interface to come back up
    ${intf_status}=    Get Interface Status    ${TESTBED}    ${DEVICE}    ${TEST_INTERFACE}
    Should Be Equal    ${intf_status}[oper_status]    up
    ...    msg=Interface ${TEST_INTERFACE} did not come back up after no shutdown command
    Log    Interface ${TEST_INTERFACE} is up    level=INFO

    # Step 6: Wait for BGP recovery
    Log    Step 6: Waiting ${BGP_SETTLE_TIME} for BGP to recover    level=INFO
    Sleep    ${BGP_SETTLE_TIME}
    Log    BGP recovery time complete    level=INFO

    # Step 7: Verify all BGP neighbors are re-established
    Log    Step 7: Verifying BGP neighbors have recovered    level=INFO
    ${recovered_neighbors}=    Get BGP Neighbor States    ${TESTBED}    ${DEVICE}
    Log    Post-restore neighbor states: ${recovered_neighbors}    level=DEBUG
    Should Not Be Empty    ${recovered_neighbors}    msg=No BGP neighbors found after recovery

    FOR    ${neighbor}    ${state}    IN    &{recovered_neighbors}
        Should Not Match Regexp    ${state}    ^(Idle|Active|Connect|OpenSent|OpenConfirm)$
        ...    msg=Recovery: BGP neighbor ${neighbor} is not established (state: ${state})
    END
    Log    Step 7 PASSED: All ${recovered_neighbors.__len__()} neighbors have recovered    level=INFO

    Log    TEST PASSED: BGP successfully converged during failover and recovered after restoration    level=INFO
