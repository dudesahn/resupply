# Pashov X-Ray + Solidity Auditor — resupply

This package records a clean-room audit of commit `5f014fd5003bba32c0cf2049992f57a768728631` using the local X-Ray workflow followed by the local Solidity Auditor `ALL` workflow.

Start with [`synthesis/final-report.md`](synthesis/final-report.md). The standard workflow report is [`solidity-auditor/resupply-pashov-ai-audit-report-20260722-002133.md`](solidity-auditor/resupply-pashov-ai-audit-report-20260722-002133.md).

## Contents

- `scope/audit-scope.txt`: exact 65-file / 8,109-nSLOC scope.
- `x-ray/`: final X-Ray readiness report, entry-point map, invariant catalog, and architecture diagram.
- `solidity-auditor/raw/`: 12 independent, verbatim lane outputs from two waves of six.
- `solidity-auditor/validation-ledger.md`: disposition of all 37 distinct raw function surfaces.
- `solidity-auditor/validation/`: four passing PoCs and their execution notes.
- `solidity-auditor/run-manifest.md`: isolation policy, hashes, lane mapping, and environment notes.
- `synthesis/final-report.md`: deduplicated result set and cross-tool synthesis.

## Result set

- 10 validated findings.
- 22 validated leads.
- 4/4 audit PoCs passed.
- 37/37 distinct raw function surfaces dispositioned.

Raw lane hypotheses are preserved for provenance and must not be interpreted as promoted findings. The validation ledger and synthesis are authoritative.
