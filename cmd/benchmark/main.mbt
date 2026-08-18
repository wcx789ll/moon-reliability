///|
/// Reproducible benchmark driver. Wall-clock timing is deliberately measured
/// by the host shell so the library stays backend-independent.
fn main {
  let records = @reliability.benchmark_dataset(2000)
  let grid = @reliability.benchmark_grid(256)
  let weibull = @reliability.ReliabilityModel::WeibullModel(
    @reliability.Weibull::new(100.0, 1.8),
  )
  let exponential = @reliability.ReliabilityModel::ExponentialModel(
    @reliability.Exponential::new(0.01),
  )
  let values = records.map(record => record.time)
  let distribution_checksum = @reliability.benchmark_distribution_kernel(
    weibull, grid, 20,
  )
  let statistics_checksum = @reliability.benchmark_statistics_kernel(values, 20)
  let survival_checksum = @reliability.benchmark_survival_kernel(records, 5)
  let system_checksum = @reliability.benchmark_system_kernel(
    [weibull, exponential],
    grid,
    10,
  )
  println("dataset_records=2000")
  println("grid_points=256")
  println("distribution_checksum=\{distribution_checksum}")
  println("statistics_checksum=\{statistics_checksum}")
  println("survival_checksum=\{survival_checksum}")
  println("system_checksum=\{system_checksum}")
}
