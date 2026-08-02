///|
/// Represents a confidence interval with lower and upper bounds.
pub struct ConfidenceInterval {
  lower : Double
  upper : Double
}

///|
/// Computes the confidence interval for a normally distributed estimate.
/// `estimate` is the point estimate.
/// `standard_error` is the standard error of the estimate.
/// `confidence_level` is the desired confidence level (e.g., 0.95 for 95%).
pub fn confidence_interval(
  estimate : Double,
  standard_error : Double,
  confidence_level : Double,
) -> ConfidenceInterval {
  if confidence_level <= 0.0 || confidence_level >= 1.0 {
    abort("confidence_level must be in (0, 1)")
  }
  let alpha = 1.0 - confidence_level
  // Two-tailed Z-score
  let z = standard_normal_inv(1.0 - alpha / 2.0)
  let margin = z * standard_error
  { lower: estimate - margin, upper: estimate + margin }
}
