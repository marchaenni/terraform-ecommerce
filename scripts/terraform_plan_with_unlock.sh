#!/usr/bin/env bash
set -euo pipefail

# Automatically retries "terraform plan" once if it fails due to a stale
# remote state lock. Locks younger than the configured threshold are
# considered legitimate and will not be force-unlocked.

STALE_AFTER_SECONDS=${TF_LOCK_STALE_AFTER_SECONDS:-900}
MAX_ATTEMPTS=${TF_LOCK_MAX_ATTEMPTS:-2}
PLAN_ARGS=("-no-color" "-input=false" "-out=tfplan")

if [[ ${TF_PLAN_EXTRA_ARGS:-} ]]; then
  # shellcheck disable=SC2206 # we intentionally rely on word splitting here
  EXTRA_ARGS=(${TF_PLAN_EXTRA_ARGS})
  PLAN_ARGS+=("${EXTRA_ARGS[@]}")
fi

PLAN_LOG=""
cleanup() {
  if [[ -n ${PLAN_LOG} && -f ${PLAN_LOG} ]]; then
    rm -f "${PLAN_LOG}"
  fi
}
trap cleanup EXIT

run_plan() {
  cleanup
  PLAN_LOG=$(mktemp -t terraform-plan-XXXXXX.log)
  set +e
  terraform plan "${PLAN_ARGS[@]}" "$@" | tee "${PLAN_LOG}"
  local exit_code=${PIPESTATUS[0]}
  set -e
  return "${exit_code}"
}

attempt=1
while (( attempt <= MAX_ATTEMPTS )); do
  echo "Running terraform plan (attempt ${attempt}/${MAX_ATTEMPTS})..."
  if run_plan "$@"; then
    exit 0
  fi

  status=$?

  if ! grep -q "Error: Error acquiring the state lock" "${PLAN_LOG}"; then
    exit "${status}"
  fi

  lock_id=$(grep -m1 'ID:' "${PLAN_LOG}" | awk '{print $3}')
  created=$(sed -n 's/.*Created:\s*//p' "${PLAN_LOG}" | head -n1 | tr -d '\r')

  if [[ -z ${lock_id} || -z ${created} ]]; then
    echo "::error::Failed to parse lock information from terraform output."
    exit "${status}"
  fi

  lock_age_seconds=$(python - <<'PY'
import datetime as dt
import re
import sys

created = sys.stdin.read().strip()
if created.endswith(' UTC'):
    created = created[:-4]
match = re.match(r'(.*\.\d{6})(\d*)( .*)', created)
if match:
    created = match.group(1) + match.group(3)
try:
    parsed = dt.datetime.strptime(created, "%Y-%m-%d %H:%M:%S.%f %z")
except ValueError:
    parsed = dt.datetime.strptime(created, "%Y-%m-%d %H:%M:%S %z")
now = dt.datetime.now(parsed.tzinfo)
age = int((now - parsed).total_seconds())
print(age)
PY
<<<"${created}")

  if [[ -z ${lock_age_seconds} ]]; then
    echo "::error::Unable to compute Terraform lock age."
    exit "${status}"
  fi

  if (( lock_age_seconds < STALE_AFTER_SECONDS )); then
    echo "::error::Terraform state lock (${lock_id}) is ${lock_age_seconds}s old, which is newer than the safety threshold (${STALE_AFTER_SECONDS}s). Aborting to avoid unlocking an active operation."
    exit "${status}"
  fi

  echo "::warning::Detected stale Terraform state lock (${lock_id}) created ${lock_age_seconds}s ago. Forcing unlock..."
  terraform force-unlock -force "${lock_id}"

  (( attempt++ ))
done

echo "::error::Unable to obtain Terraform state lock after ${MAX_ATTEMPTS} attempts."
exit 1
