# Benchmark Results

This is a deterministic smoke benchmark for the public reliability-engineering APIs. It is intended to make performance regressions and accidental result changes visible; it is not a hardware-neutral performance claim.

## Workload

- 2,000 deterministic lifetime records.
- 256 probability-distribution grid points.
- Summary statistics, survival estimates, and a system reliability calculation.
- Native executable: `cmd/benchmark`.
- Toolchain recorded on 2026-08-22: MoonBit `0.1.20260814`, Moonc `0.10.8+8606a5800`.

Run it with:

```text
moon run --target native cmd/benchmark
```

## Result checksum

```text
dataset_records=2000
grid_points=256
distribution_checksum=1101.741461248007
statistics_checksum=4699.373130613841
survival_checksum=5.0008898911681365
system_checksum=63197846.817043595
```

The checksum lines are the acceptance signal: the same toolchain and input generation should produce the same values within the printed precision.

## Local timing sample

Five consecutive PowerShell `Measure-Command` samples around `moon run --target native cmd/benchmark` on the completed checkout were:

```text
1550.67 ms, 275.58 ms, 310.87 ms, 284.70 ms, 293.34 ms
```

The first run was a cold rebuild (`1550.67 ms`). The four warm runs averaged `291.12 ms`, with a minimum of `275.58 ms` and a maximum of `310.87 ms`.

These timings include the command startup/build behavior of the local MoonBit installation and therefore should be compared only with repeated runs on the same class of environment.
