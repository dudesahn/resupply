# Raw Solidity Auditor lanes

These files are the verbatim outputs of 12 independent Solidity Auditor specialty agents. All agents received the same 65-file source bundle and the final X-Ray report, entry-point map, and invariant map as orientation only.

The lanes ran in exactly two waves:

- Wave 1: math/precision, access control, economic security, execution trace, invariant, and periphery.
- Wave 2: first principles, asymmetry, boundary, numerical gap, trust gap, and flow gap.

Each lane was prohibited from reading another lane, `.audit`, prior reports, the ytranche findings, or X-Ray working notes. Raw hypotheses are not final results; see `../validation-ledger.md` for the fixed-gate dispositions and the synthesis report for promoted findings and retained leads.
