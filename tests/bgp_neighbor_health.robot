"""
Robot Framework test suite for BGP neighbor health validation on Nexus.

Validates that all BGP neighbors on Nexus devices are in established state.
"""

*** Settings ***
Documentation    BGP neighbor health validation for Cisco Nexus (NX-OS) switches
Resource         keywords.robot
Suite Setup      Set Test Variables


*** Variables ***
${TESTBED}           testbed/nexus_testbed.yaml
${DEVICE}            nxos-spine-1


*** Keywords ***
Set Test Variables
    [Documentation]    Initialize test variables
    # Testbed and device are set above; can be overridden via CLI:
    # robot --variable TESTBED:/path/to/testbed.yaml bgp_neighbor_health.robot
    No Operation


*** Test Cases ***
All BGP Neighbors Are Established on Nexus-1
    [Documentation]    Validates that all configured BGP neighbors are in established state
    ...
    ...    For NX-OS, an established neighbor is indicated by a numeric value
    ...    (prefix count) in the state field. Text values like 'Idle', 'Active',
    ...    'Connect' indicate the neighbor is not established.
    [Tags]    bgp    critical    nxos    routing
    ${neighbors}=    Get BGP Neighbor States    ${TESTBED}    ${DEVICE}
    Should Not Be Empty    ${neighbors}    msg=No BGP neighbors found on ${DEVICE}
    FOR    ${neighbor}    ${state}    IN    &{neighbors}
        Should Not Match Regexp    ${state}    ^(Idle|Active|Connect|OpenSent|OpenConfirm)$
        ...    msg=BGP neighbor ${neighbor} is not established (state: ${state})
    END
