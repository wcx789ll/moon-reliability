///|
/// Service-level agreement availability policy.
pub struct SlaPolicy {
  window : Double
  promised_availability : Double
  credit_rate : Double
  maximum_credit : Double
}

///|
pub fn sla_policy(
  window~ : Double,
  promised_availability~ : Double,
  credit_rate~ : Double,
  maximum_credit~ : Double,
) -> SlaPolicy {
  if window <= 0.0 ||
    promised_availability <= 0.0 ||
    promised_availability > 1.0 ||
    credit_rate < 0.0 ||
    maximum_credit < 0.0 {
    abort("invalid SLA policy")
  }
  { window, promised_availability, credit_rate, maximum_credit }
}

///|
pub struct SlaResult {
  observed_availability : Double
  downtime : Double
  breach : Bool
  credit : Double
  error_budget_remaining : Double
  confidence : MetricEstimate
}

///|
pub fn sla_result(
  observed_availability~ : Double,
  downtime~ : Double,
  breach~ : Bool,
  credit~ : Double,
  error_budget_remaining~ : Double,
  confidence~ : MetricEstimate,
) -> SlaResult {
  {
    observed_availability,
    downtime,
    breach,
    credit,
    error_budget_remaining,
    confidence,
  }
}

///|
pub fn evaluate_sla(
  failures : Array[Double],
  policy : SlaPolicy,
  observation_window : Double,
) -> SlaResult {
  if observation_window <= 0.0 {
    abort("observation window must be positive")
  }
  let downtime = failures.fold(init=0.0, (total, duration) => total + duration)
  let availability = (1.0 - downtime / observation_window).max(0.0).min(1.0)
  let breach = availability < policy.promised_availability
  let credit = if breach {
    ((policy.promised_availability - availability) * policy.credit_rate).min(
      policy.maximum_credit,
    )
  } else {
    0.0
  }
  let budget = (availability - policy.promised_availability).max(0.0) *
    observation_window
  let confidence = defect_rate(failures.length(), failures.length().max(1))
  sla_result(
    observed_availability=availability,
    downtime~,
    breach~,
    credit~,
    error_budget_remaining=budget,
    confidence~,
  )
}

///|
pub fn monthly_downtime_budget(
  window : Double,
  promised_availability : Double,
) -> Double {
  window * (1.0 - promised_availability)
}

///|
pub fn availability_from_incidents(
  incident_durations : Array[Double],
  window : Double,
) -> Double {
  if window <= 0.0 {
    abort("window must be positive")
  }
  (1.0 -
  incident_durations.fold(init=0.0, (sum, duration) => sum + duration) / window).max(
    0.0,
  )
}

///|
pub fn availability_slo_curve(
  model : ReliabilityModel,
  windows : Array[Double],
) -> Array[MetricEstimate] {
  windows.map(window => {
    let availability = model.survival(window)
    metric_estimate(
      estimate=availability,
      lower=availability,
      upper=availability,
      confidence_level=1.0,
    )
  })
}

///|
pub fn burn_rate(
  observed : Double,
  target : Double,
  interval : Double,
) -> Double {
  if target <= 0.0 || interval <= 0.0 {
    abort("invalid burn-rate arguments")
  }
  (1.0 - observed) / (1.0 - target)
}

///|
pub fn alert_severity(burn : Double) -> String {
  if burn >= 14.0 {
    "critical"
  } else if burn >= 4.0 {
    "high"
  } else if burn >= 1.0 {
    "elevated"
  } else {
    "normal"
  }
}
