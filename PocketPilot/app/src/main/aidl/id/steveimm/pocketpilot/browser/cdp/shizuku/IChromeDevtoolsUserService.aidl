// Shell-UID binder restricted to Chrome's fixed DevTools socket.
// Caller-controlled socket names would expose other privileged services.
package id.steveimm.pocketpilot.browser.cdp.shizuku;

interface IChromeDevtoolsUserService {
    /** Exchange an HTTP request with Chrome within the deadline. Throws when the socket is inaccessible. */
    byte[] exchange(in byte[] request, int timeoutMs);

    /** Start a loopback relay requiring X-PocketPilot-Token. Reusing the same token returns the same port.
     * Empty or changed tokens are rejected. The service lifecycle owns the relay. */
    int startTcpRelay(String authToken);

    /** Tear down the user service process. */
    void destroy();

    /** Return the current lowercase Wi-Fi BSSID, or null when unavailable. */
    String getCurrentBssid();

    /** Enable wireless debugging for this BSSID. Repeated calls are safe. */
    boolean enableWirelessDebugging(String bssid);

    /** Return the wireless ADB port, or -1 when it is not listening. */
    int getAdbWirelessPort();

    /** Return the pairing port discovered within five seconds, or -1. Call disablePairing after pairing. */
    int enablePairingByQrCode(String name, String psk);

    /** Stop pairing and log any failure. */
    void disablePairing();

    /** Return adb_keys content, or null on read failure. Use adbKeysReadStatus to distinguish denial from absence. */
    String readAdbKeys();

    /** Return 0 for readable, 1 for denied, 2 for missing, and 3 for other failures.
     * Keep these values stable. A denied read differs from a missing authorization file. */
    int adbKeysReadStatus();

    /** Atomically replace adb_keys. The caller must preserve unrelated authorized keys.
     * Returns false on IO failure. New keys apply to the next handshake without restarting adbd. */
    boolean writeAdbKeys(String content);
}
