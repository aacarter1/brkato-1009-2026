#!/usr/bin/env python
"""
pyATS test: validate BGP neighbors are healthy on Cisco Nexus (NX-OS) switches.

Uses Genie BGP Ops to learn neighbor session state and fails if any configured
neighbor is not in the expected state (default: Established).

Run:
  pyats run job tests/bgp_neighbor_health.py --testbed testbed/nexus_testbed.yaml
  # or
  python tests/bgp_neighbor_health.py --testbed testbed/nexus_testbed.yaml
"""

import logging

from pyats import aetest
from pyats.log.utils import banner
from genie.conf import Genie
from genie.abstract import Lookup

log = logging.getLogger(__name__)

EXPECTED_STATE = "established"
# Optional: restrict check to these VRF names (empty = all VRFs with neighbors)
VRF_ALLOWLIST = []


def _collect_neighbors(bgp_info):
    """Yield (vrf_name, neighbor_id, session_state) from learned BGP structure."""
    instances = bgp_info.get("instance", {})
    for instance_data in instances.values():
        vrfs = instance_data.get("vrf", {})
        for vrf_name, vrf_data in vrfs.items():
            if VRF_ALLOWLIST and vrf_name not in VRF_ALLOWLIST:
                continue
            for neighbor_id, neighbor_data in vrf_data.get("neighbor", {}).items():
                state = neighbor_data.get("session_state")
                if state is not None:
                    yield vrf_name, neighbor_id, state


def _unhealthy_neighbors(bgp_info, expected_state=EXPECTED_STATE):
    """Return list of neighbors whose session_state is not expected."""
    expected = expected_state.lower()
    unhealthy = []
    for vrf, neighbor, state in _collect_neighbors(bgp_info):
        if state.lower() != expected:
            unhealthy.append(
                {
                    "vrf": vrf,
                    "neighbor": neighbor,
                    "state": state,
                    "expected": expected_state,
                }
            )
    return unhealthy


###################################################################
# COMMON SETUP
###################################################################


class CommonSetup(aetest.CommonSetup):
    """Connect to all Nexus devices in the testbed."""

    @aetest.subsection
    def connect(self, testbed):
        genie_testbed = Genie.init(testbed)
        self.parent.parameters["testbed"] = genie_testbed

        devices = []
        for device in genie_testbed.devices.values():
            log.info(banner(f"Connecting to {device.name}"))
            try:
                device.connect(via="cli", learn_hostname=True)
            except Exception as exc:
                self.failed(
                    f"Could not connect to {device.name}: {exc}",
                    goto=["common_cleanup"],
                )
            devices.append(device)

        if not devices:
            self.failed("No devices defined in testbed", goto=["common_cleanup"])

        self.parent.parameters["devices"] = devices


###################################################################
# TESTCASES
###################################################################


class BgpNeighborHealth(aetest.Testcase):
    """Verify every learned BGP neighbor is in the expected session state."""

    @aetest.setup
    def learn_bgp_on_devices(self):
        self.bgp_by_device = {}

        for device in self.parent.parameters["devices"]:
            log.info(banner(f"Learning BGP on {device.name}"))
            abstract = Lookup.from_device(device)
            bgp = abstract.ops.bgp.bgp.Bgp(device)

            try:
                bgp.learn()
            except Exception as exc:
                self.failed(f"BGP learn failed on {device.name}: {exc}")

            if not getattr(bgp, "info", None):
                self.failed(f"No BGP information returned from {device.name}")

            self.bgp_by_device[device.name] = bgp.info

    @aetest.test
    def all_neighbors_established(self):
        """Fail if any neighbor is not Established (or configured expected state)."""
        all_unhealthy = {}

        for device_name, bgp_info in self.bgp_by_device.items():
            neighbors = list(_collect_neighbors(bgp_info))
            if not neighbors:
                log.warning(
                    "%s: no BGP neighbors found in learned data "
                    "(is BGP configured and running?)",
                    device_name,
                )
                continue

            unhealthy = _unhealthy_neighbors(bgp_info)
            if unhealthy:
                all_unhealthy[device_name] = unhealthy
                for entry in unhealthy:
                    log.error(
                        "%s vrf=%s neighbor=%s state=%s (expected %s)",
                        device_name,
                        entry["vrf"],
                        entry["neighbor"],
                        entry["state"],
                        entry["expected"],
                    )
            else:
                log.info(
                    "%s: all %d neighbor(s) are %s",
                    device_name,
                    len(neighbors),
                    EXPECTED_STATE,
                )

        if all_unhealthy:
            self.failed(
                "One or more BGP neighbors are not healthy",
                extra={"unhealthy_neighbors": all_unhealthy},
            )

        self.passed("All BGP neighbors are healthy")


###################################################################
# COMMON CLEANUP
###################################################################


class CommonCleanup(aetest.CommonCleanup):
    """Disconnect from devices."""

    @aetest.subsection
    def disconnect(self):
        testbed = self.parent.parameters.get("testbed")
        if not testbed:
            return
        for device in testbed.devices.values():
            if device.is_connected():
                log.info("Disconnecting from %s", device.name)
                device.disconnect()


if __name__ == "__main__":
    aetest.main()
