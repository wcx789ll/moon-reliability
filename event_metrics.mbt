///|
/// Event-level engineering metrics derived from mixed lifetime records.
pub fn mttf(records : Array[LifeObservation]) -> Double {
  let failures = records.filter_map(record => {
    if record.is_failure() {
      Some(record.time)
    } else {
      None
    }
  })
  if failures.is_empty() {
    0.0
  } else {
    mean(failures)
  }
}

///|
pub fn mtbf_from_events(event_times : Array[Double]) -> Double {
  if event_times.length() < 2 {
    abort("MTBF requires two event times")
  }
  let intervals = Array::makei(event_times.length() - 1, i => {
    event_times[i + 1] - event_times[i]
  })
  mean(intervals)
}

///|
pub fn failure_fraction(records : Array[LifeObservation]) -> Double {
  if records.is_empty() {
    return 0.0
  }
  observed_event_count(records).to_double() / records.length().to_double()
}

///|
pub fn expected_remaining_life(
  model : ReliabilityModel,
  age : Double,
  horizon : Double,
) -> Double {
  if age < 0.0 || horizon <= age {
    abort("invalid remaining-life interval")
  }
  let step = (horizon - age) / 400.0
  let mut total = 0.0
  for i in 0..<400 {
    let x0 = age + i.to_double() * step
    let x1 = x0 + step
    let conditional0 = model.survival(x0) / model.survival(age).max(1.0e-300)
    let conditional1 = model.survival(x1) / model.survival(age).max(1.0e-300)
    total += (conditional0 + conditional1) * step / 2.0
  }
  total
}

///|
pub fn percentile_life(
  model : ReliabilityModel,
  percentiles : Array[Double],
) -> Array[MetricEstimate] {
  percentiles.map(p => {
    let life = model_quantile(model, p)
    metric_estimate(estimate=life, lower=life, upper=life, confidence_level=1.0)
  })
}

///|
pub fn life_ratio(
  model : ReliabilityModel,
  first_probability : Double,
  second_probability : Double,
) -> Double {
  model_quantile(model, first_probability) /
  model_quantile(model, second_probability)
}

///|
pub fn reliability_margin(
  model : ReliabilityModel,
  mission_time : Double,
  target : Double,
) -> Double {
  model.survival(mission_time) - target
}

///|
pub fn mission_success_probability(
  models : Array[ReliabilityModel],
  mission_time : Double,
) -> Double {
  series_reliability(models.map(model => model.survival(mission_time)))
}

///|
pub fn downtime_budget_from_availability(
  horizon : Double,
  target_availability : Double,
) -> Double {
  if horizon < 0.0 || target_availability < 0.0 || target_availability > 1.0 {
    abort("invalid availability budget")
  }
  horizon * (1.0 - target_availability)
}
