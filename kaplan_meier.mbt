///|
/// Non-parametric survival curve and its summary metrics.
pub struct SurvivalCurve {
  points : Array[SurvivalPoint]
  median : Double?
  restricted_mean : Double
  total_events : Int
}

///|
pub fn SurvivalCurve::points(self : SurvivalCurve) -> Array[SurvivalPoint] {
  self.points.copy()
}

///|
pub fn SurvivalCurve::survival_at(
  self : SurvivalCurve,
  time : Double,
) -> Double {
  let mut value = 1.0
  for point in self.points {
    if point.time <= time {
      value = point.survival
    }
  }
  value
}

///|
pub fn SurvivalCurve::hazard_at(self : SurvivalCurve, time : Double) -> Double {
  let mut value = 0.0
  for point in self.points {
    if point.time <= time {
      value = point.cumulative_hazard
    }
  }
  value
}

///|
pub fn SurvivalCurve::median_life(self : SurvivalCurve) -> Double? {
  self.median
}

///|
pub fn kaplan_meier(records : Array[LifeObservation]) -> SurvivalCurve {
  if records.is_empty() {
    abort("kaplan_meier requires observations")
  }
  let sorted = sort_observations(records)
  let points : Array[SurvivalPoint] = []
  let mut i = 0
  let mut survival = 1.0
  let mut cumulative_hazard = 0.0
  let mut greenwood = 0.0
  let mut median : Double? = None
  let mut total_events = 0
  let mut previous_time = 0.0
  let mut restricted_mean = 0.0
  while i < sorted.length() {
    let time = sorted[i].time
    let mut events = 0
    let mut censored = 0
    let mut j = i
    while j < sorted.length() && sorted[j].time == time {
      if sorted[j].is_failure() {
        events += 1
      } else {
        censored += 1
      }
      j += 1
    }
    let mut risk = 0
    for record in sorted {
      if record.time >= time {
        risk += 1
      }
    }
    if time > previous_time {
      restricted_mean += survival * (time - previous_time)
    }
    if events > 0 && risk > events {
      survival *= (risk - events).to_double() / risk.to_double()
      greenwood += events.to_double() /
        (risk.to_double() * (risk - events).to_double())
      cumulative_hazard += events.to_double() / risk.to_double()
      total_events += events
      if median is None && survival <= 0.5 {
        median = Some(time)
      }
    } else if events > 0 {
      survival = 0.0
      cumulative_hazard += 1.0e6
      total_events += events
      if median is None {
        median = Some(time)
      }
    }
    points.push(
      survival_point(
        time~,
        at_risk=risk,
        events~,
        censored~,
        survival~,
        standard_error=(survival * survival * greenwood).sqrt(),
        cumulative_hazard~,
      ),
    )
    previous_time = time
    i = j
  }
  restricted_mean += survival * (previous_time - previous_time)
  { points, median, restricted_mean, total_events }
}

///|
pub fn nelson_aalen(records : Array[LifeObservation]) -> SurvivalCurve {
  if records.is_empty() {
    abort("nelson_aalen requires observations")
  }
  let sorted = sort_observations(records)
  let points : Array[SurvivalPoint] = []
  let mut i = 0
  let mut cumulative_hazard = 0.0
  let mut variance = 0.0
  let mut median : Double? = None
  let mut total_events = 0
  while i < sorted.length() {
    let time = sorted[i].time
    let mut events = 0
    let mut censored = 0
    let mut j = i
    while j < sorted.length() && sorted[j].time == time {
      if sorted[j].is_failure() {
        events += 1
      } else {
        censored += 1
      }
      j += 1
    }
    let mut risk = 0
    for record in sorted {
      if record.time >= time {
        risk += 1
      }
    }
    if risk > 0 && events > 0 {
      cumulative_hazard += events.to_double() / risk.to_double()
      variance += events.to_double() / (risk.to_double() * risk.to_double())
      total_events += events
      if median is None && @math.exp(-cumulative_hazard) <= 0.5 {
        median = Some(time)
      }
    }
    points.push(
      survival_point(
        time~,
        at_risk=risk,
        events~,
        censored~,
        survival=@math.exp(-cumulative_hazard),
        standard_error=variance.sqrt(),
        cumulative_hazard~,
      ),
    )
    i = j
  }
  let mut restricted_mean = 0.0
  let mut last_time = 0.0
  let mut last_survival = 1.0
  for point in points {
    restricted_mean += last_survival * (point.time - last_time)
    last_time = point.time
    last_survival = point.survival
  }
  { points, median, restricted_mean, total_events }
}

///|
pub fn survival_confidence_interval(
  point : SurvivalPoint,
  confidence_level : Double,
) -> MetricEstimate {
  if confidence_level <= 0.0 || confidence_level >= 1.0 {
    abort("invalid confidence level")
  }
  let z = standard_normal_inv(0.5 + confidence_level / 2.0)
  let log_survival = safe_log_probability(point.survival)
  let scale = if point.survival <= 0.0 {
    1.0
  } else {
    point.standard_error / point.survival
  }
  let lower = @math.exp(log_survival - z * scale)
  let upper = @math.exp(log_survival + z * scale)
  metric_estimate(
    estimate=point.survival,
    lower=lower.min(1.0),
    upper=upper.min(1.0),
    confidence_level~,
  )
}
