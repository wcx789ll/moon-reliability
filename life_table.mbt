///|
/// Actuarial life-table interval.
pub struct LifeTableInterval {
  lower : Double
  upper : Double
  exposed : Double
  failures : Int
  withdrawals : Int
  failure_probability : Double
  survival_probability : Double
  hazard : Double
}

///|
pub fn life_table_interval(
  lower~ : Double,
  upper~ : Double,
  exposed~ : Double,
  failures~ : Int,
  withdrawals~ : Int,
  failure_probability~ : Double,
  survival_probability~ : Double,
  hazard~ : Double,
) -> LifeTableInterval {
  {
    lower,
    upper,
    exposed,
    failures,
    withdrawals,
    failure_probability,
    survival_probability,
    hazard,
  }
}

///|
pub struct LifeTable {
  intervals : Array[LifeTableInterval]
  total_failures : Int
  restricted_mean : Double
  final_survival : Double
}

///|
pub fn life_table(
  intervals~ : Array[LifeTableInterval],
  total_failures~ : Int,
  restricted_mean~ : Double,
  final_survival~ : Double,
) -> LifeTable {
  { intervals, total_failures, restricted_mean, final_survival }
}

///|
/// Construct an actuarial life table over a regular grid. Withdrawals are
/// treated as half-interval exposures, which is the standard engineering
/// life-table approximation when inspection times are not exact.
pub fn actuarial_life_table(
  records : Array[LifeObservation],
  grid : Array[Double],
) -> LifeTable {
  if records.is_empty() || grid.length() < 2 {
    abort("life table needs records and two grid points")
  }
  let intervals : Array[LifeTableInterval] = []
  let mut survival = 1.0
  let mut restricted_mean = 0.0
  let mut total_failures = 0
  for i in 0..<(grid.length() - 1) {
    let lower = grid[i]
    let upper = grid[i + 1]
    let width = upper - lower
    if width <= 0.0 {
      abort("life-table grid must increase")
    }
    let mut failures = 0
    let mut withdrawals = 0
    let mut exposed = 0.0
    for record in records {
      if record.time >= lower {
        exposed += record.weight * width
      }
      if record.time >= lower && record.time < upper {
        if record.is_failure() {
          failures += 1
        } else {
          withdrawals += 1
        }
      }
    }
    let effective_exposed = (exposed / width - 0.5 * withdrawals.to_double()).max(
      1.0e-12,
    )
    let probability = failures.to_double() / effective_exposed
    let interval_survival = (1.0 - probability).max(0.0)
    let midpoint_survival = survival * (1.0 - probability / 2.0)
    restricted_mean += width * midpoint_survival
    survival *= interval_survival
    total_failures += failures
    intervals.push(
      life_table_interval(
        lower~,
        upper~,
        exposed=effective_exposed,
        failures~,
        withdrawals~,
        failure_probability=probability,
        survival_probability=survival,
        hazard=-safe_log_probability(interval_survival) / width,
      ),
    )
  }
  life_table(
    intervals~,
    total_failures~,
    restricted_mean~,
    final_survival=survival,
  )
}

///|
pub fn LifeTable::survival_at(self : LifeTable, time : Double) -> Double {
  let mut result = 1.0
  for interval in self.intervals {
    if interval.upper <= time {
      result = interval.survival_probability
    }
  }
  result
}

///|
pub fn LifeTable::hazard_at(self : LifeTable, time : Double) -> Double {
  for interval in self.intervals {
    if time >= interval.lower && time < interval.upper {
      return interval.hazard
    }
  }
  0.0
}

///|
pub fn LifeTable::intervals(self : LifeTable) -> Array[LifeTableInterval] {
  self.intervals.copy()
}

///|
pub fn exposure_time(
  records : Array[LifeObservation],
  horizon : Double,
) -> Double {
  if horizon < 0.0 {
    abort("horizon must be non-negative")
  }
  records.fold(init=0.0, (total, record) => {
    total + record.weight * record.time.min(horizon)
  })
}

///|
pub fn failure_rate_estimate(
  records : Array[LifeObservation],
  horizon : Double,
) -> MetricEstimate {
  let events = records.fold(init=0, (total, record) => {
    if record.is_failure() && record.time <= horizon {
      total + 1
    } else {
      total
    }
  })
  let exposure = exposure_time(records, horizon)
  if exposure == 0.0 {
    abort("no exposure time")
  }
  let rate = events.to_double() / exposure
  let lower = if events == 0 {
    0.0
  } else {
    rate * (1.0 - 1.96 / events.to_double().sqrt()).max(0.0)
  }
  let upper = rate * (1.0 + 1.96 / events.to_double().max(1.0).sqrt())
  metric_estimate(estimate=rate, lower~, upper~, confidence_level=0.95)
}

///|
pub fn cumulative_exposure(
  records : Array[LifeObservation],
  grid : Array[Double],
) -> Array[Double] {
  grid.map(time => exposure_time(records, time))
}

///|
pub fn interval_event_counts(
  records : Array[LifeObservation],
  grid : Array[Double],
) -> Array[Int] {
  if grid.length() < 2 {
    abort("event-count grid needs two points")
  }
  Array::makei(grid.length() - 1, i => {
    let mut count = 0
    for record in records {
      if record.is_failure() &&
        record.time >= grid[i] &&
        record.time < grid[i + 1] {
        count += 1
      }
    }
    count
  })
}
