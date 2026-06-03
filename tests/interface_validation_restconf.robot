"""
Robot Framework test suite for interface validation via RESTCONF API.

Validates interface administrative state on Cisco IOS-XE routers using
the RESTCONF API and IETF interfaces YANG model.
"""

*** Settings ***
Documentation    Interface validation via RESTCONF on Cisco IOS-XE routers
Resource         keywords.robot
Suite Setup      Set Test Variables


*** Variables ***
${TESTBED}           testbed/nexus_testbed.yaml
${DEVICE}            NONE


*** Keywords ***
Set Test Variables
    [Documentation]    Initialize test variables
    # This topology has no RESTCONF-capable device configured in the testbed.
    Skip    No RESTCONF-capable device is defined in testbed/nexus_testbed.yaml


*** Test Cases ***
All Interfaces Are Enabled on IOS-XE Router via RESTCONF
    [Documentation]    Validates that all interfaces are enabled (not shutdown) using RESTCONF API
    ...
    ...    This test uses the RESTCONF API to query the IETF interfaces YANG model
    ...    and ensures no interfaces are administratively disabled. The RESTCONF
    ...    approach provides programmatic, structured data access without relying
    ...    on CLI parsers, making it ideal for integration with automation platforms.
    ...
    ...    Prerequisites:
    ...    - Device must have RESTCONF enabled (ip http secure-server + restconf)
    ...    - Credentials must be set in environment variables
    ...    - REST connection must be configured in testbed
    [Tags]    interfaces    restconf    compliance    critical    iosxe

    # Query all interfaces and their enabled state via RESTCONF
    Log    Querying all interfaces via RESTCONF on ${DEVICE}    level=INFO
    ${all_interfaces}=    Get All Interfaces Enabled RESTCONF    ${TESTBED}    ${DEVICE}
    
    # Verify we got interface data
    Should Not Be Empty    ${all_interfaces}    msg=No interfaces found on ${DEVICE} via RESTCONF
    Log    Found ${all_interfaces.__len__()} interfaces on ${DEVICE}    level=INFO

    # Check for disabled interfaces
    ${disabled_interfaces}=    Get Disabled Interfaces RESTCONF    ${TESTBED}    ${DEVICE}
    
    # Fail if any interfaces are disabled
    IF    ${disabled_interfaces}
        ${disabled_str}=    Evaluate    ', '.join(${disabled_interfaces})
        FAIL    The following interfaces are disabled (shutdown): ${disabled_str}
    ELSE
        Log    SUCCESS: All ${all_interfaces.__len__()} interfaces are enabled    level=INFO
    END


Verify Interface Enabled State Details
    [Documentation]    Displays detailed enabled state for all interfaces
    ...
    ...    This test queries all interfaces and provides a detailed report of their
    ...    administrative state, useful for auditing and compliance validation.
    [Tags]    interfaces    restconf    audit    iosxe

    # Get all interface states
    Log    Fetching interface details via RESTCONF on ${DEVICE}    level=INFO
    ${all_interfaces}=    Get All Interfaces Enabled RESTCONF    ${TESTBED}    ${DEVICE}
    
    Should Not Be Empty    ${all_interfaces}    msg=No interfaces returned from RESTCONF query
    
    # Report on each interface
    Log    Interface Administrative State Report on ${DEVICE}    level=INFO
    Log    ${'-' * 60}    level=INFO
    
    FOR    ${intf_name}    ${enabled}    IN    &{all_interfaces}
        ${status}=    Set Variable If    ${enabled}    ENABLED    DISABLED
        Log    ${intf_name}: ${status}    level=INFO
    END
    
    Log    ${'-' * 60}    level=INFO
    ${enabled_count}=    Evaluate    sum(1 for v in ${all_interfaces}.values() if v)
    ${disabled_count}=    Evaluate    len(${all_interfaces}) - ${enabled_count}
    Log    Summary: ${enabled_count} enabled, ${disabled_count} disabled    level=INFO
