*** Settings ***
Documentation    BDD-style BGP failover scenario for Cisco Nexus nxos-spine-1
...
...    Scenario: BGP recovers after Ethernet1/1 is shut down and restored
...      Given BGP is healthy on nxos-spine-1
...      When  Ethernet1/1 is shut down
...      Then  BGP neighbors are impacted
...      When  Ethernet1/1 is restored
...      Then  BGP has fully recovered
...
...    Robot Framework natively strips Given/When/Then/And/But keyword prefixes,
...    mapping each step directly to the matching keyword in keywords.robot.
Resource         keywords.robot
Test Teardown    Ensure Interface Is Restored    ${TESTBED}    ${DEVICE}    ${INTERFACE}


*** Variables ***
${TESTBED}      testbed/nexus_testbed.yaml
${DEVICE}       nxos-spine-1
${INTERFACE}    Ethernet1/1


*** Test Cases ***
BGP Recovers After Ethernet1/1 Is Shut Down on nxos-spine-1
    [Documentation]    BDD scenario validating BGP convergence resilience on nxos-spine-1.
    ...
    ...    Precondition: All BGP neighbors must be established before the test begins.
    ...    Action:       Ethernet1/1 is administratively shut down to simulate a link failure.
    ...    Outcome:      BGP recovers and all neighbors are re-established after interface restoration.
    [Tags]    bgp    failover    convergence    bdd    nxos    critical

    # ── Given ─────────────────────────────────────────────────────────────────
    Given BGP Is Healthy On Device    ${TESTBED}    ${DEVICE}

    # ── When (fault injection) ─────────────────────────────────────────────────
    When Interface Is Shut Down On Device    ${TESTBED}    ${DEVICE}    ${INTERFACE}

    # ── Then (impact verification) ────────────────────────────────────────────
    Then BGP Neighbors Are Impacted On Device    ${TESTBED}    ${DEVICE}    settle_time=5s

    # ── When (recovery action) ────────────────────────────────────────────────
    When Interface Is Restored On Device    ${TESTBED}    ${DEVICE}    ${INTERFACE}

    # ── Then (convergence verification) ───────────────────────────────────────
    Then BGP Has Fully Recovered On Device    ${TESTBED}    ${DEVICE}    settle_time=10s
