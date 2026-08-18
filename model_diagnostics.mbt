///|
/// Probability-integral-transform diagnostic for a fitted model.
pub struct DiagnosticResult {
  statistic : Double
  p_value : Double
  passed : Bool
  residuals : Array[Double]
  message : String
}

///|
pub fn diagnostic_result(
  statistic~ : Double,
  p_value~ : Double,
  passed~ : Bool,
  residuals~ : Array[Double],
  message~ : String,
) -> DiagnosticResult {
  { statistic, p_value, passed, residuals, message }
}

///|
pub fn probability_integral_residuals(
  model : ReliabilityModel,
  records : Array[LifeObservation],
) -> Array[Double] {
  records.map(record => {
    let probability = if record.is_failure() {
      model.cdf(record.time)
    } else {
      model.survival(record.time)
    }
    standard_normal_inv(probability.max(1.0e-9).min(1.0 - 1.0e-9))
  })
}

///|
pub fn kolmogorov_smirnov_d(values : Array[Double]) -> Double {
  if values.is_empty() {
    abort("KS statistic requires values")
  }
  let sorted = values.copy()
  sorted.sort()
  let mut maximum = 0.0
  for i in 0..<sorted.length() {
    let empirical = (i + 1).to_double() / sorted.length().to_double()
    let expected = standard_normal_cdf(sorted[i])
    maximum = maximum.max((empirical - expected).abs())
  }
  maximum
}

///|
pub fn ks_normal_diagnostic(
  values : Array[Double],
  alpha : Double,
) -> DiagnosticResult {
  let normalized = values.map(value => {
    (value - mean(values)) / variance(values).sqrt().max(1.0e-12)
  })
  let statistic = kolmogorov_smirnov_d(normalized)
  let critical = 1.36 / values.length().to_double().sqrt()
  diagnostic_result(
    statistic~,
    p_value=if statistic < critical { 0.5 } else { 0.01 },
    passed=statistic < critical || alpha <= 0.0,
    residuals=normalized,
    message=if statistic < critical {
      "no strong normality evidence"
    } else {
      "residual shape differs from normal"
    },
  )
}

///|
pub fn quantile_quantile_pairs(
  model : ReliabilityModel,
  observations : Array[Double],
) -> Array[(Double, Double)] {
  let sorted = observations.copy()
  sorted.sort()
  Array::makei(sorted.length(), i => {
    let p = (i.to_double() + 0.5) / sorted.length().to_double()
    (model_quantile(model, p), sorted[i])
  })
}

///|
pub fn residual_summary(diagnostic : DiagnosticResult) -> SampleSummary {
  summarize(diagnostic.residuals.map(value => failure(value)))
}

///|
pub fn calibration_slope(
  predicted : Array[Double],
  observed : Array[Double],
) -> Double {
  linear_regression(predicted, observed).coefficients[1]
}

///|
pub fn calibration_intercept(
  predicted : Array[Double],
  observed : Array[Double],
) -> Double {
  linear_regression(predicted, observed).coefficients[0]
}
