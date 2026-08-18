///|
/// Information-criterion comparison for fitted reliability models.
pub struct ModelComparison {
  names : Array[String]
  log_likelihoods : Array[Double]
  aic : Array[Double]
  bic : Array[Double]
  preferred_aic : Int
  preferred_bic : Int
}

///|
pub fn model_comparison(
  names~ : Array[String],
  log_likelihoods~ : Array[Double],
  aic~ : Array[Double],
  bic~ : Array[Double],
  preferred_aic~ : Int,
  preferred_bic~ : Int,
) -> ModelComparison {
  { names, log_likelihoods, aic, bic, preferred_aic, preferred_bic }
}

///|
pub fn compare_fits(fits : Array[FitResult]) -> ModelComparison {
  if fits.is_empty() {
    abort("model comparison requires fits")
  }
  let names = fits.map(fit => fit.distribution)
  let log_likelihoods = fits.map(fit => fit.log_likelihood)
  let aics = fits.map(fit => fit.aic)
  let bics = fits.map(fit => fit.bic)
  let mut best_aic = 0
  let mut best_bic = 0
  for i in 1..<fits.length() {
    if aics[i] < aics[best_aic] {
      best_aic = i
    }
    if bics[i] < bics[best_bic] {
      best_bic = i
    }
  }
  model_comparison(
    names~,
    log_likelihoods~,
    aic=aics,
    bic=bics,
    preferred_aic=best_aic,
    preferred_bic=best_bic,
  )
}

///|
pub fn akaike_weights(comparison : ModelComparison) -> Array[Double] {
  let minimum = min_value(comparison.aic)
  let raw = comparison.aic.map(value => @math.exp(-0.5 * (value - minimum)))
  let total = raw.fold(init=0.0, (sum, value) => sum + value)
  raw.map(value => value / total)
}

///|
pub fn likelihood_ratio(first : FitResult, second : FitResult) -> Double {
  2.0 * (second.log_likelihood - first.log_likelihood)
}

///|
pub fn cross_entropy(
  model : ReliabilityModel,
  records : Array[LifeObservation],
) -> Double {
  -model.log_likelihood(records) / records.length().to_double()
}

///|
pub fn root_mean_square_error(
  actual : Array[Double],
  predicted : Array[Double],
) -> Double {
  if actual.length() != predicted.length() || actual.is_empty() {
    abort("RMSE arrays mismatch")
  }
  let mut total = 0.0
  for i in 0..<actual.length() {
    let error = actual[i] - predicted[i]
    total += error * error
  }
  (total / actual.length().to_double()).sqrt()
}

///|
pub fn mean_absolute_percentage_error(
  actual : Array[Double],
  predicted : Array[Double],
) -> Double {
  if actual.length() != predicted.length() || actual.is_empty() {
    abort("MAPE arrays mismatch")
  }
  let mut total = 0.0
  for i in 0..<actual.length() {
    total += (actual[i] - predicted[i]).abs() / actual[i].abs().max(1.0e-12)
  }
  total / actual.length().to_double()
}

///|
pub fn validation_split(
  values : Array[Double],
  fraction : Double,
) -> (Array[Double], Array[Double]) {
  if fraction <= 0.0 || fraction >= 1.0 {
    abort("validation fraction must be in (0, 1)")
  }
  let split = (values.length().to_double() * fraction).to_int()
  (values[:split].to_owned(), values[split:].to_owned())
}
