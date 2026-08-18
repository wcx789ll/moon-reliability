///|
/// One point of a cumulative-incidence curve.
pub struct CumulativeIncidencePoint {
  time : Double
  at_risk : Int
  events_by_cause : Array[Int]
  survival : Double
  incidence_by_cause : Array[Double]
}

///|
pub fn cumulative_incidence_point(
  time~ : Double,
  at_risk~ : Int,
  events_by_cause~ : Array[Int],
  survival~ : Double,
  incidence_by_cause~ : Array[Double],
) -> CumulativeIncidencePoint {
  { time, at_risk, events_by_cause, survival, incidence_by_cause }
}

///|
pub struct CompetingRiskCurve {
  points : Array[CumulativeIncidencePoint]
  causes : Int
  final_incidence : Array[Double]
}

///|
pub fn competing_risk_curve(
  points~ : Array[CumulativeIncidencePoint],
  causes~ : Int,
  final_incidence~ : Array[Double],
) -> CompetingRiskCurve {
  { points, causes, final_incidence }
}

///|
/// Cause values are stored in the observation's `cause` field; cause zero is
/// treated as ordinary failure and causes start at one for competing events.
pub fn cumulative_incidence(
  records : Array[LifeObservation],
  causes : Int,
) -> CompetingRiskCurve {
  if records.is_empty() || causes <= 0 {
    abort("competing risks requires records and causes")
  }
  let sorted = sort_observations(records)
  let points : Array[CumulativeIncidencePoint] = []
  let incidence = Array::make(causes, 0.0)
  let mut survival = 1.0
  let mut i = 0
  while i < sorted.length() {
    let time = sorted[i].time
    let events = Array::make(causes, 0)
    let mut censored = 0
    let mut j = i
    while j < sorted.length() && sorted[j].time == time {
      if sorted[j].is_failure() {
        let cause = sorted[j].cause.max(1).min(causes)
        events[cause - 1] += 1
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
    let total_events = events.fold(init=0, (s, value) => s + value)
    if risk > 0 && total_events > 0 {
      for cause in 0..<causes {
        incidence[cause] += survival *
          events[cause].to_double() /
          risk.to_double()
      }
      survival *= 1.0 - total_events.to_double() / risk.to_double()
    }
    points.push(
      cumulative_incidence_point(
        time~,
        at_risk=risk,
        events_by_cause=events,
        survival~,
        incidence_by_cause=incidence.copy(),
      ),
    )
    ignore(censored)
    i = j
  }
  competing_risk_curve(points~, causes~, final_incidence=incidence)
}

///|
pub fn CompetingRiskCurve::incidence_at(
  self : CompetingRiskCurve,
  cause : Int,
  time : Double,
) -> Double {
  if cause < 1 || cause > self.causes {
    abort("cause outside curve")
  }
  let mut result = 0.0
  for point in self.points {
    if point.time <= time {
      result = point.incidence_by_cause[cause - 1]
    }
  }
  result
}

///|
pub fn cause_specific_hazard(
  records : Array[LifeObservation],
  cause : Int,
) -> Array[MetricEstimate] {
  if cause <= 0 {
    abort("cause must be positive")
  }
  let sorted = sort_observations(records)
  let result : Array[MetricEstimate] = []
  let mut i = 0
  while i < sorted.length() {
    let time = sorted[i].time
    let mut events = 0
    while i < sorted.length() && sorted[i].time == time {
      if sorted[i].is_failure() && sorted[i].cause == cause {
        events += 1
      }
      i += 1
    }
    let mut risk = 0
    for record in sorted {
      if record.time >= time {
        risk += 1
      }
    }
    if events > 0 && risk > 0 {
      let value = events.to_double() / risk.to_double()
      result.push(
        metric_estimate(
          estimate=value,
          lower=value,
          upper=value,
          confidence_level=1.0,
        ),
      )
    }
  }
  result
}
