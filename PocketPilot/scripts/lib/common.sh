#!/usr/bin/env bash

list_connected_devices() {
    adb devices | awk 'NR > 1 && $2 == "device" {print $1}'
}

select_device() {
    local devices preferred physical candidates count
    devices="$(list_connected_devices)"
    preferred="${ANDROID_SERIAL:-}"
    if [[ -z "$devices" ]]; then
        printf '%s\n' 'No connected ADB device.' >&2
        return 1
    fi
    if [[ -n "$preferred" ]]; then
        if printf '%s\n' "$devices" | grep -Fxq -- "$preferred"; then
            printf '%s\n' "$preferred"
            return 0
        fi
        printf 'Requested ADB device is unavailable: %s\n' "$preferred" >&2
        return 1
    fi

    physical="$(printf '%s\n' "$devices" | grep -v '^emulator-' || true)"
    candidates="${physical:-$devices}"
    count="$(printf '%s\n' "$candidates" | awk 'END {print NR}')"
    if [[ "$count" -ne 1 ]]; then
        printf '%s\n' 'Multiple ADB devices match; set ANDROID_SERIAL.' >&2
        return 1
    fi
    printf '%s\n' "$candidates"
}

validate_output_tag() {
    if [[ ! "$1" =~ ^[a-zA-Z0-9_-][a-zA-Z0-9._-]*$ ]]; then
        printf '%s\n' 'Output tags may contain letters, digits, underscores, dots, and hyphens, and must not start with a dot.' >&2
        return 1
    fi
}
