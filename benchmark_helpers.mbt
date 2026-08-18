///|
/// Deterministic kernels used by the benchmark CLI and regression tests.
pub fn benchmark_distribution_kernel(
  model : ReliabilityModel,
  grid : Array[Double],
  repetitions : Int,
) -> Double {
  let mut checksum = 0.0
  for _ in 0..<repetitions {
    for time in grid {
      checksum += model.survival(time) + model_hazard(model, time)
    }
  }
  checksum
}

///|
pub fn benchmark_statistics_kernel(
  values : Array[Double],
  repetitions : Int,
) -> Double {
  let mut checksum = 0.0
  for _ in 0..<repetitions {
    checksum += mean(values) +
      variance(values, unbiased=false).sqrt() +
      quantile(values, 0.9)
  }
  checksum
}

///|
pub fn benchmark_survival_kernel(
  records : Array[LifeObservation],
  repetitions : Int,
) -> Double {
  let mut checksum = 0.0
  for _ in 0..<repetitions {
    let curve = kaplan_meier(records)
    checksum += curve.survival_at(10.0) + curve.hazard_at(10.0)
  }
  checksum
}

///|
pub fn benchmark_system_kernel(
  models : Array[ReliabilityModel],
  times : Array[Double],
  repetitions : Int,
) -> Double {
  let mut checksum = 0.0
  for _ in 0..<repetitions {
    for time in times {
      checksum += series_hazard(models, time) + parallel_hazard(models, time)
    }
  }
  checksum
}

///|
pub fn benchmark_result_from_measurement(
  name : String,
  iterations : Int,
  elapsed_micros : Int64,
  checksum : Double,
) -> BenchmarkResult {
  let throughput = if elapsed_micros <= 0 {
    0.0
  } else {
    iterations.to_double() * 1.0e6 / elapsed_micros.to_double()
  }
  benchmark_result(
    name~,
    iterations~,
    elapsed_micros~,
    checksum~,
    operations_per_second=throughput,
  )
}

///|
pub fn benchmark_dataset(size : Int) -> Array[LifeObservation] {
  let failures = sample_weibull(20260818, 100.0, 1.8, size)
  failures.map(value => failure(value))
}

///|
pub fn benchmark_grid(size : Int) -> Array[Double] {
  linspace(0.1, 500.0, size)
}
