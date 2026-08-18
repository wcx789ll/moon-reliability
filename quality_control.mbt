///|
/// Control limits for reliability-monitoring streams.
pub struct ControlLimits {
  center : Double
  upper : Double
  lower : Double
  sigma : Double
  violations : Array[Int]
}

///|
pub fn control_limits(
  center~ : Double,
  upper~ : Double,
  lower~ : Double,
  sigma~ : Double,
  violations~ : Array[Int],
) -> ControlLimits {
  { center, upper, lower, sigma, violations }
}

///|
pub fn shewhart_limits(
  values : Array[Double],
  sigma_multiplier : Double,
) -> ControlLimits {
  let center = mean(values)
  let sigma = variance(values).sqrt()
  let upper = center + sigma_multiplier * sigma
  let lower = center - sigma_multiplier * sigma
  let violations = values.foldi(init=[], (i, result, value) => {
    if value > upper || value < lower {
      result.push(i)
    }
    result
  })
  control_limits(center~, upper~, lower~, sigma~, violations~)
}

///|
pub fn ewma(
  values : Array[Double],
  lambda : Double,
  target : Double,
) -> Array[Double] {
  if lambda <= 0.0 || lambda > 1.0 {
    abort("EWMA lambda must be in (0, 1]")
  }
  if values.is_empty() {
    return []
  }
  let result = Array::make(values.length(), target)
  let mut state = target
  for i in 0..<values.length() {
    state = lambda * values[i] + (1.0 - lambda) * state
    result[i] = state
  }
  result
}

///|
pub fn cusum(
  values : Array[Double],
  target : Double,
  allowance : Double,
) -> (Array[Double], Array[Double]) {
  let positive = Array::make(values.length(), 0.0)
  let negative = Array::make(values.length(), 0.0)
  for i in 0..<values.length() {
    let previous_positive = if i == 0 { 0.0 } else { positive[i - 1] }
    let previous_negative = if i == 0 { 0.0 } else { negative[i - 1] }
    positive[i] = (previous_positive + values[i] - target - allowance).max(0.0)
    negative[i] = (previous_negative + target - values[i] - allowance).max(0.0)
  }
  (positive, negative)
}

///|
pub fn capability_indices(
  values : Array[Double],
  lower_spec : Double,
  upper_spec : Double,
) -> (Double, Double, Double) {
  let center = mean(values)
  let sigma = variance(values).sqrt()
  if sigma == 0.0 {
    return (1.0e300, 1.0e300, 1.0e300)
  }
  let cpu = (upper_spec - center) / (3.0 * sigma)
  let cpl = (center - lower_spec) / (3.0 * sigma)
  (cpu.min(cpl), cpu, cpl)
}

///|
pub fn defect_rate(defects : Int, opportunities : Int) -> MetricEstimate {
  if defects < 0 || opportunities <= 0 || defects > opportunities {
    abort("invalid defect counts")
  }
  let rate = defects.to_double() / opportunities.to_double()
  let error = 1.96 * (rate * (1.0 - rate) / opportunities.to_double()).sqrt()
  metric_estimate(
    estimate=rate,
    lower=(rate - error).max(0.0),
    upper=(rate + error).min(1.0),
    confidence_level=0.95,
  )
}

///|
pub fn poisson_rate(count : Int, exposure : Double) -> MetricEstimate {
  if count < 0 || exposure <= 0.0 {
    abort("invalid Poisson rate input")
  }
  let rate = count.to_double() / exposure
  let error = 1.96 * rate.max(1.0 / exposure).sqrt() / exposure.sqrt()
  metric_estimate(
    estimate=rate,
    lower=(rate - error).max(0.0),
    upper=rate + error,
    confidence_level=0.95,
  )
}

///|
pub fn run_rules(
  values : Array[Double],
  limits : ControlLimits,
) -> Array[String] {
  let result : Array[String] = []
  for i in 0..<values.length() {
    if values[i] > limits.upper {
      result.push("point \{i}: above upper limit")
    }
    if values[i] < limits.lower {
      result.push("point \{i}: below lower limit")
    }
    if i >= 2 &&
      values[i] > limits.center &&
      values[i - 1] > limits.center &&
      values[i - 2] > limits.center {
      result.push("points \{i - 2}-\{i}: run above center")
    }
  }
  result
}
