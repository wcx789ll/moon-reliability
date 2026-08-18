# Benchmark Results

This is a deterministic smoke benchmark for the public reliability-engineering APIs. It is intended to make performance regressions and accidental result changes visible; it is not a hardware-neutral performance claim.

## Workload

- 2,000 deterministic lifetime records.
- 256 probability-distribution grid points.
- Summary statistics, survival estimates, and a system reliability calculation.
- Native executable: `cmd/benchmark`.
- Toolchain recorded on 2026-08-18: MoonBit `0.1.20260807`, Moonc `0.10.7+bc794d341`.

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
1444.34 ms, 319.47 ms, 314.43 ms, 313.26 ms, 314.20 ms
```

The first run was a cold rebuild (`1444.34 ms`). The four warm runs averaged `315.34 ms`, with a minimum of `313.26 ms` and a maximum of `319.47 ms`.

These timings include the command startup/build behavior of the local MoonBit installation and therefore should be compared only with repeated runs on the same class of environment.
