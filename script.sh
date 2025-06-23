#!/bin/bash
set -ex

if [ -n "${GITHUB_WORKSPACE}" ]; then
  cd "${GITHUB_WORKSPACE}/${INPUT_WORKDIR}" || exit
fi

export REVIEWDOG_GITHUB_API_TOKEN="${INPUT_GITHUB_TOKEN}"

handle_error() {
    local exit_code=$?
    if [ -s "$tempfile" ]; then
        echo "Error: $(cat "$tempfile")"
    fi
    rm -f "$tempfile" 2>/dev/null
    exit "$exit_code"
}

echo '::group::🔗💀 Installing linkspector ... https://github.com/UmbrellaDocs/linkspector'
npm install -g @umbrelladocs/linkspector@0.4.5
echo '🔗💀 linkspector version:'
linkspector --version
echo '::endgroup::'

echo '::group::🔗💀 Setting up Chrome Linux Sandbox'
# Based on the instructions found here: https://chromium.googlesource.com/chromium/src/+/main/docs/security/apparmor-userns-restrictions.md
if [ "$(lsb_release -rs)" = "24.04" ]; then
  echo 0 | sudo tee /proc/sys/kernel/apparmor_restrict_unprivileged_userns
  echo 'Done'
fi

echo '::endgroup::'

echo '::group:: Running linkspector with reviewdog 🐶 ...'
trap 'handle_error' ERR
tempfile=$(mktemp)
linkspector_output=$(linkspector check -c "${INPUT_CONFIG_FILE}" -j 2> "$tempfile")

tempfile=$(mktemp)
reviewdog_output=$(echo "$linkspector_output" 2> "$tempfile" | reviewdog -f=rdjson \
    -name="${INPUT_TOOL_NAME}" \
    -reporter="${INPUT_REPORTER}" \
    -filter-mode="${INPUT_FILTER_MODE}" \
    -fail-level="${INPUT_FAIL_LEVEL}" \
    -level="${INPUT_LEVEL}" \
    "${INPUT_REVIEWDOG_FLAGS}")
exit_code=$?

echo "$linkspector_output"
echo "$reviewdog_output"
exit_code=$?
echo '::endgroup::'

if [ "${INPUT_SHOW_STATS}" = "true" ]; then
  echo '::group:: Running linkspector stats ...'
  linkspector check -c "${INPUT_CONFIG_FILE}" -s || true
  echo '::endgroup::'
fi

exit $exit_code
