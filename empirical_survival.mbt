///|
/// Empirical distribution function with deterministic tie handling.
pub struct EmpiricalDistribution {
  sorted_times : Array[Double]
  failure_counts : Array[Int]
  cumulative_failures : Array[Int]
  total : Int
}

///|
pub fn empirical_distribution(
  records : Array[LifeObservation],
) -> EmpiricalDistribution {
  let sorted = sort_observations(records)
  let times : Array[Double] = []
  let failures : Array[Int] = []
  let cumulative : Array[Int] = []
  let mut cumulative_failures = 0
  for record in sorted {
    let index = times.search(record.time)
    match index {
      Some(i) =>
        if record.is_failure() {
          failures[i] += 1
          cumulative_failures += 1
        }
      None => {
        times.push(record.time)
        failures.push(if record.is_failure() { 1 } else { 0 })
        if record.is_failure() {
          cumulative_failures += 1
        }
        cumulative.push(cumulative_failures)
      }
    }
    if times.length() > 0 {
      cumulative[times.length() - 1] = cumulative_failures
    }
  }
  {
    sorted_times: times,
    failure_counts: failures,
    cumulative_failures: cumulative,
    total: records.length(),
  }
}

///|
pub fn EmpiricalDistribution::cdf(
  self : EmpiricalDistribution,
  time : Double,
) -> Double {
  if self.total == 0 {
    return 0.0
  }
  let mut result = 0
  for i in 0..<self.sorted_times.length() {
    if self.sorted_times[i] <= time {
      result = self.cumulative_failures[i]
    }
  }
  result.to_double() / self.total.to_double()
}

///|
pub fn EmpiricalDistribution::survival(
  self : EmpiricalDistribution,
  time : Double,
) -> Double {
  1.0 - self.cdf(time)
}

///|
pub fn EmpiricalDistribution::quantile(
  self : EmpiricalDistribution,
  p : Double,
) -> Double {
  if self.sorted_times.is_empty() {
    abort("empirical quantile requires data")
  }
  if p < 0.0 || p > 1.0 {
    abort("p must be in [0, 1]")
  }
  for i in 0..<self.sorted_times.length() {
    if self.cdf(self.sorted_times[i]) >= p {
      return self.sorted_times[i]
    }
  }
  self.sorted_times[self.sorted_times.length() - 1]
}

///|
pub fn EmpiricalDistribution::support(
  self : EmpiricalDistribution,
) -> Array[Double] {
  self.sorted_times.copy()
}

///|
pub fn EmpiricalDistribution::probability_mass(
  self : EmpiricalDistribution,
) -> Array[Double] {
  self.failure_counts.map(count => count.to_double() / self.total.to_double())
}

///|
/// Compute a mean residual life curve at selected inspection times.
pub fn mean_residual_life(
  records : Array[LifeObservation],
  grid : Array[Double],
) -> Array[Double] {
  let failures = records.filter_map(record => {
    if record.is_failure() {
      Some(record.time)
    } else {
      None
    }
  })
  grid.map(time => {
    let tail = failures.filter(value => value > time)
    if tail.is_empty() {
      0.0
    } else {
      mean(tail) - time
    }
  })
}

///|
pub fn empirical_hazard(
  records : Array[LifeObservation],
) -> Array[MetricEstimate] {
  let sorted = sort_observations(records)
  let result : Array[MetricEstimate] = []
  let mut i = 0
  let mut risk = sorted.length()
  while i < sorted.length() {
    let time = sorted[i].time
    let mut events = 0
    let mut censored = 0
    while i < sorted.length() && sorted[i].time == time {
      if sorted[i].is_failure() {
        events += 1
      } else {
        censored += 1
      }
      i += 1
    }
    if events > 0 {
      let hazard = events.to_double() / risk.to_double()
      result.push(
        metric_estimate(
          estimate=time,
          lower=hazard,
          upper=hazard,
          confidence_level=1.0,
        ),
      )
    }
    risk -= events + censored
  }
  result
}
