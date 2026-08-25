#!/usr/bin/env bash
# Deterministic reference cases for the orchestration state transitions.

set -u

fail=0
assert_eq() {
  local id="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "  ok: $id -> $actual"
  else
    echo "FAIL: $id expected '$expected', got '$actual'"
    fail=1
  fi
}

derive_change_state() {
  local automated_complete="$1" status="$2" snapshot="$3" verdict="$4" pending="$5" mr="$6"
  if [[ "$automated_complete" != yes ]]; then echo in-progress; return; fi
  if [[ "$status" != impl_reviewed || "$snapshot" != current ]]; then echo in-progress; return; fi
  if [[ "$verdict" == REJECTED || ( "$verdict" == NEEDS_ATTENTION && "$pending" == yes ) ]]; then
    echo needs-triage; return
  fi
  if [[ "$mr" == open ]]; then echo awaiting-merge; else echo awaiting-closeout; fi
}

primary_event() {
  local outcome="$1" stop="$2" verification="$3"
  if [[ "$verification" == REJECTED ]]; then echo CHANGE_REJECTED
  elif [[ "$outcome" == completed && "$verification" == NEEDS_ATTENTION ]]; then echo CHANGE_NEEDS_ATTENTION
  elif [[ "$outcome" == completed ]]; then echo CHANGE_COMPLETED
  elif [[ "$stop" == gate-failure ]]; then echo CHANGE_STOPPED
  elif [[ "$stop" == structural-mismatch ]]; then echo SPEC_MISMATCH
  elif [[ "$stop" == missing-prep || "$stop" == human-decision ]]; then echo HUMAN_DECISION_REQUIRED
  else echo ENVIRONMENT
  fi
}

profile_for() {
  local signal="$1"
  case "$signal" in
    auth|permissions|secrets|irreversible) echo critical ;;
    schema|migration|cross-module|research) echo deep ;;
    bounded-feature) echo standard ;;
    mechanical) echo light ;;
    *) echo standard ;;
  esac
}

carrier_for() {
  local model_override="$1" interaction="$2" profile_diff="$3"
  if [[ "$model_override" == yes && "$interaction" == supported && "$profile_diff" == yes ]]; then
    echo profiled-executor
  else
    echo inline-advisory
  fi
}

effort_resolution() {
  local effort_override="$1" requested="$2"
  if [[ "$effort_override" == yes ]]; then echo "$requested"; else echo host-default; fi
}

archive_gate() {
  local integrated="$1" clean="$2" target="$3" synced="$4"
  if [[ "$integrated" == yes && "$clean" == yes && "$target" == yes && "$synced" == yes ]]; then
    echo archive
  else
    echo stop
  fi
}

review_floor() {
  local parent="$1" strongest="$2"
  local p=0 s=0
  case "$parent" in light) p=1;; standard) p=2;; deep) p=3;; critical) p=4;; esac
  case "$strongest" in light) s=1;; standard) s=2;; deep) s=3;; critical) s=4;; esac
  if (( p >= s )); then echo "$parent"; else echo "$strongest"; fi
}

retry_profile() {
  local current="$1" stronger_helps="$2" critical_signal="$3"
  if [[ "$stronger_helps" != yes ]]; then echo "$current"; return; fi
  case "$current" in
    light) echo standard ;;
    standard) echo deep ;;
    deep) [[ "$critical_signal" == yes ]] && echo critical || echo deep ;;
    *) echo critical ;;
  esac
}

source_is_current() {
  local selected="$1" evidence="$2" fingerprint="$3"
  [[ "$selected" == "$evidence" && "$fingerprint" == match ]] && echo current || echo stale
}

impact_is_resolved() {
  local change="$1" run="$2" impact="$3" ack_change="$4" ack_run="$5" ack_impact="$6"
  [[ "$change" == "$ack_change" && "$run" == "$ack_run" && "$impact" == "$ack_impact" ]] \
    && echo resolved || echo unresolved
}

echo "orchestration evals"

assert_eq VF-pending in-progress "$(derive_change_state no impl_reviewed current APPROVED no none)"
assert_eq VF-stale-review in-progress "$(derive_change_state yes implemented stale APPROVED no none)"
assert_eq VF-current-approved awaiting-closeout "$(derive_change_state yes impl_reviewed current APPROVED no none)"
assert_eq VF-current-rejected needs-triage "$(derive_change_state yes impl_reviewed current REJECTED yes none)"
assert_eq VF-source-exact current "$(source_is_current factory-log:run-2 factory-log:run-2 match)"
assert_eq VF-old-file-cannot-win stale "$(source_is_current factory-log:run-2 review:reviews/impl-review.md match)"
assert_eq VF-fingerprint-mismatch stale "$(source_is_current factory-log:run-2 factory-log:run-2 mismatch)"
assert_eq MR-open-awaiting awaiting-merge "$(derive_change_state yes impl_reviewed current APPROVED no open)"

assert_eq IM-completed CHANGE_COMPLETED "$(primary_event completed none APPROVED)"
assert_eq IM-completed-impact-primary-unchanged CHANGE_COMPLETED "$(primary_event completed none APPROVED)"
assert_eq IM-structural SPEC_MISMATCH "$(primary_event stopped structural-mismatch none)"
assert_eq IM-exact-ack resolved "$(impact_is_resolved A 2 roadmap A 2 roadmap)"
assert_eq IM-old-run-ack unresolved "$(impact_is_resolved A 2 roadmap A 1 roadmap)"
assert_eq IM-other-change-ack unresolved "$(impact_is_resolved A 2 roadmap B 2 roadmap)"

assert_eq RP-mechanical light "$(profile_for mechanical)"
assert_eq RP-migration deep "$(profile_for migration)"
assert_eq RP-auth critical "$(profile_for auth)"
assert_eq RP-direct-light-carrier profiled-executor "$(carrier_for yes supported yes)"
assert_eq RP-no-model inline-advisory "$(carrier_for no supported yes)"
assert_eq RP-model-only-effort host-default "$(effort_resolution no low)"
assert_eq RP-effort-override low "$(effort_resolution yes low)"
assert_eq RP-critical-review-floor critical "$(review_floor critical light)"
assert_eq RP-deterministic-retry-same light "$(retry_profile light no no)"
assert_eq RP-evidence-escalation standard "$(retry_profile light yes no)"
assert_eq RP-deep-no-critical deep "$(retry_profile deep yes no)"

assert_eq MR-synced-archive archive "$(archive_gate yes yes yes yes)"
assert_eq MR-wrong-branch stop "$(archive_gate yes yes no yes)"
assert_eq MR-dirty-target stop "$(archive_gate yes no yes yes)"
assert_eq MR-unsynced-target stop "$(archive_gate yes yes yes no)"

if [[ $fail -eq 0 ]]; then
  echo "validate-orchestration-evals: ALL CASES PASSED"
else
  echo "validate-orchestration-evals: FAILURES ABOVE"
fi
exit $fail
