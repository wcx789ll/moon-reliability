///|
/// Delta-method uncertainty for a scalar transform.
pub fn delta_method(
  mean_value : Double,
  standard_error : Double,
  transform : (Double) -> Double,
) -> MetricEstimate {
  if standard_error < 0.0 {
    abort("standard error must be non-negative")
  }
  let estimate = transform(mean_value)
  let step = standard_error.max(1.0e-6)
  let derivative = (transform(mean_value + step) - transform(mean_value - step)) /
    (2.0 * step)
  let output_error = derivative.abs() * standard_error
  metric_estimate(
    estimate~,
    lower=estimate - 1.96 * output_error,
    upper=estimate + 1.96 * output_error,
    confidence_level=0.95,
  )
}

///|
pub fn lognormal_mean_uncertainty(
  mu : Double,
  sigma : Double,
  mu_error : Double,
  sigma_error : Double,
) -> MetricEstimate {
  propagate_independent_uncertainty([mu, sigma], [mu_error, sigma_error], values => {
    @math.exp(values[0] + values[1] * values[1] / 2.0)
  })
}

///|
pub fn confidence_to_standard_error(
  lower : Double,
  upper : Double,
  confidence : Double,
) -> Double {
  let z = standard_normal_inv(0.5 + confidence / 2.0)
  (upper - lower) / (2.0 * z)
}

///|
pub fn combine_estimates(
  estimates : Array[Double],
  standard_errors : Array[Double],
) -> MetricEstimate {
  if estimates.length() != standard_errors.length() || estimates.is_empty() {
    abort("estimate arrays mismatch")
  }
  let mut precision = 0.0
  let mut weighted = 0.0
  for i in 0..<estimates.length() {
    let p = 1.0 / (standard_errors[i] * standard_errors[i]).max(1.0e-24)
    precision += p
    weighted += p * estimates[i]
  }
  let value = weighted / precision
  let error = 1.0 / precision.sqrt()
  metric_estimate(
    estimate=value,
    lower=value - 1.96 * error,
    upper=value + 1.96 * error,
    confidence_level=0.95,
  )
}

///|
pub fn poisson_confidence(
  count : Int,
  exposure : Double,
  confidence : Double,
) -> MetricEstimate {
  let estimate = count.to_double() / exposure
  let error = standard_normal_inv(0.5 + confidence / 2.0) *
    estimate.max(1.0 / exposure).sqrt() /
    exposure.sqrt()
  metric_estimate(
    estimate~,
    lower=(estimate - error).max(0.0),
    upper=estimate + error,
    confidence_level=confidence,
  )
}

///|
pub fn transform_interval(
  metric : MetricEstimate,
  transform : (Double) -> Double,
) -> MetricEstimate {
  let transformed = transform(metric.estimate)
  let lower = transform(metric.lower)
  let upper = transform(metric.upper)
  metric_estimate(
    estimate=transformed,
    lower=lower.min(upper),
    upper=lower.max(upper),
    confidence_level=metric.confidence_level,
  )
}
