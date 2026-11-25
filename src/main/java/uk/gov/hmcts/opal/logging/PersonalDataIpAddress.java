package uk.gov.hmcts.opal.logging;

import com.google.common.net.HostAndPort;
import com.google.common.net.InetAddresses;

/** Best-effort audit metadata; never resolves hostnames or invents an originating address. */
public final class PersonalDataIpAddress {
    private PersonalDataIpAddress() {
    }

    public static String normalize(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        String trimmed = value.trim();
        if (InetAddresses.isInetAddress(trimmed)) {
            return trimmed;
        }
        try {
            HostAndPort address = HostAndPort.fromString(trimmed);
            if ((address.hasPort() || trimmed.equals("[" + address.getHost() + "]"))
                && InetAddresses.isInetAddress(address.getHost())) {
                return address.getHost();
            }
        } catch (IllegalArgumentException invalidAddress) {
            return null;
        }
        return null;
    }
}
