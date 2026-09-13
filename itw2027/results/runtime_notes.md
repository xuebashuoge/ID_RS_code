# Local validation notes

MATLAB R2025a on this Mac successfully completed the numerical integration suite, including exact noiseless enumeration, the adversarial small case, all three function families with packed BP at 0 and 6 dB, and validation/reuse of completed waterfall and rate-sweep points. See `integration_test.log`.

Two separate, very short MATLAB processes printed successful cache-reuse validation and then crashed in the native `ddux::matlab::LicenseLogger::initialize` thread during shutdown (exit 137). Running the same entry-point checks as part of the full integration suite completed successfully. No simulation assertion failed in those short processes. This is a local MATLAB runtime observation; the Linux Slurm jobs use the existing R2024b server module and were not submitted here.

Python's finite-rate tests pass. The builder validates 27 noiseless cells, 22 verified/5 skipped adversarial cases, and 126 fixed-sample noisy points. All scripts pass Bash syntax checks. The parameter table compiles in a standalone IEEEtran 10-point document without an overfull box. This is not a full manuscript page-layout check.

During the matched-length import, MATLAB again crashed in its native LicenseLogger thread after reporting all 22 exports complete. All 22 compact files were independently loaded by SciPy and passed the full data checks. A /tmp versus /private/tmp path-normalization issue in the selective importer was also corrected; relative paths are now obtained only after canonicalization and a prefix check.
