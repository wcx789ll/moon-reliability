///|
/// Local sensitivity result for a reliability metric.
pub struct SensitivityPoint {
  parameter : String
  baseline : Double
  perturbed : Double
  absolute_change : Double
  relative_change : Double
  elasticity : Double
}

///|
pub fn sensitivity_point(
  parameter~ : String,
  baseline~ : Double,
  perturbed~ : Double,
  absolute_change~ : Double,
  relative_change~ : Double,
  elasticity~ : Double,
) -> SensitivityPoint {
  {
    parameter,
    baseline,
    perturbed,
    absolute_change,
    relative_change,
    elasticity,
  }
}

///|
pub fn finite_difference_sensitivity(
  parameter : String,
  baseline_parameter : Double,
  baseline_metric : Double,
  perturbation : Double,
  evaluator : (Double) -> Double,
) -> SensitivityPoint {
  if perturbation == 0.0 || baseline_parameter == 0.0 {
    abort("invalid sensitivity perturbation")
  }
  let perturbed_parameter = baseline_parameter * (1.0 + perturbation)
  let perturbed = evaluator(perturbed_parameter)
  let change = perturbed - baseline_metric
  sensitivity_point(
    parameter~,
    baseline=baseline_metric,
    perturbed~,
    absolute_change=change,
    relative_change=change / baseline_metric.max(1.0e-300),
    elasticity=change / baseline_metric.max(1.0e-300) / perturbation,
  )
}

///|
pub fn distribution_sensitivity(
  model : ReliabilityModel,
  time : Double,
  parameter : String,
  perturbation : Double,
) -> SensitivityPoint {
  let baseline = model.survival(time)
  let evaluator = match model {
    ExponentialModel(value) =>
      _ => {
        Exponential::new(value.lambda * (1.0 + perturbation)).reliability(time)
      }
    WeibullModel(value) =>
      _ => {
        Weibull::new(value.scale, value.shape * (1.0 + perturbation)).reliability(
          time,
        )
      }
    LognormalModel(value) =>
      _ => {
        Lognormal::new(value.mu, value.sigma * (1.0 + perturbation)).reliability(
          time,
        )
      }
    GammaModel(value) =>
      _ => {
        GammaDistribution::new(value.shape * (1.0 + perturbation), value.rate).reliability(
          time,
        )
      }
    LogLogisticModel(value) =>
      _ => {
        LogLogistic::new(value.scale, value.shape * (1.0 + perturbation)).reliability(
          time,
        )
      }
  }
  finite_difference_sensitivity(
    parameter, 1.0, baseline, perturbation, evaluator,
  )
}

///|
pub fn tornado_order(
  points : Array[SensitivityPoint],
) -> Array[SensitivityPoint] {
  let result = points.copy()
  result.sort_by((left, right) => {
    if left.absolute_change.abs() > right.absolute_change.abs() {
      -1
    } else if left.absolute_change.abs() < right.absolute_change.abs() {
      1
    } else {
      0
    }
  })
  result
}

///|
pub fn one_at_a_time(
  names : Array[String],
  baselines : Array[Double],
  metric : (Array[Double]) -> Double,
  fraction : Double,
) -> Array[SensitivityPoint] {
  if names.length() != baselines.length() {
    abort("sensitivity names and values mismatch")
  }
  let baseline = metric(baselines)
  Array::makei(names.length(), i => {
    let changed = baselines.copy()
    changed[i] *= 1.0 + fraction
    let perturbed = metric(changed)
    sensitivity_point(
      parameter=names[i],
      baseline~,
      perturbed~,
      absolute_change=perturbed - baseline,
      relative_change=(perturbed - baseline) / baseline.max(1.0e-300),
      elasticity=(perturbed - baseline) / baseline.max(1.0e-300) / fraction,
    )
  })
}

///|
pub fn propagate_independent_uncertainty(
  means : Array[Double],
  standard_errors : Array[Double],
  evaluator : (Array[Double]) -> Double,
) -> MetricEstimate {
  if means.length() != standard_errors.length() {
    abort("uncertainty arrays mismatch")
  }
  let baseline = evaluator(means)
  let mut variance_sum = 0.0
  for i in 0..<means.length() {
    let plus = means.copy()
    plus[i] += standard_errors[i]
    let minus = means.copy()
    minus[i] -= standard_errors[i]
    let derivative = (evaluator(plus) - evaluator(minus)) /
      (2.0 * standard_errors[i].max(1.0e-12))
    variance_sum += derivative *
      derivative *
      standard_errors[i] *
      standard_errors[i]
  }
  let error = variance_sum.sqrt()
  metric_estimate(
    estimate=baseline,
    lower=baseline - 1.96 * error,
    upper=baseline + 1.96 * error,
    confidence_level=0.95,
  )
}

///|
pub fn threshold_crossing(
  model : ReliabilityModel,
  target_reliability : Double,
  start : Double,
  stop : Double,
  steps : Int,
) -> Double? {
  let grid = linspace(start, stop, steps)
  for time in grid {
    if model.survival(time) <= target_reliability {
      return Some(time)
    }
  }
  None
}
