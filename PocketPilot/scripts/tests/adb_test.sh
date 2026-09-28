#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

adb() {
    [[ "$1" == devices ]]
    printf 'List of devices attached\n%s\n' "$ADB_TEST_DEVICES"
}

assert_device() {
    local actual
    actual="$(select_device)"
    [[ "$actual" == "$1" ]] || { printf 'Expected %s, got %s\n' "$1" "$actual" >&2; exit 1; }
}

assert_no_device() {
    local actual
    if actual="$(select_device 2>/dev/null)"; then
        printf 'Unexpected device selected: %s\n' "$actual" >&2
        exit 1
    fi
    [[ -z "$actual" ]]
}

unset ANDROID_SERIAL
ADB_TEST_DEVICES=''
assert_no_device
ADB_TEST_DEVICES=$'phone-a\tunauthorized\nphone-b\toffline'
assert_no_device
ADB_TEST_DEVICES=$'emulator-5554\tdevice'
assert_device emulator-5554
ADB_TEST_DEVICES=$'emulator-5554\tdevice\nphone-a\tdevice'
assert_device phone-a
ANDROID_SERIAL=emulator-5554
assert_device emulator-5554
ANDROID_SERIAL=missing
assert_no_device
unset ANDROID_SERIAL
ADB_TEST_DEVICES=$'phone-a\tdevice\nphone-b\tdevice'
assert_no_device
ADB_TEST_DEVICES=$'emulator-5554\tdevice\nemulator-5556\tdevice'
assert_no_device
printf '%s\n' 'ADB selection: 8 cases passed.'

for tag in latest run-1 ctn_1 task.2; do validate_output_tag "$tag"; done
for tag in . .. ../outside a/b /tmp/output 'two words' ''; do
    if validate_output_tag "$tag" 2>/dev/null; then
        printf 'Unsafe output tag accepted: %s\n' "$tag" >&2
        exit 1
    fi
done
printf '%s\n' 'Output tags: 11 cases passed.'
