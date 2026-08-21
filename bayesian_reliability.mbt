///|
/// Beta posterior for a Bernoulli reliability or availability probability.
pub struct ReliabilityBetaPosterior {
  alpha : Double
  beta : Double
  prior_alpha : Double
  prior_beta : Double
  successes : Int
  failures : Int
  exposure : Double
  label : String
}

///|
pub fn reliability_beta_prior(
  alpha : Double,
  beta : Double,
  label : String,
) -> ReliabilityBetaPosterior {
  if alpha <= 0.0 || beta <= 0.0 {
    abort("beta prior parameters must be positive")
  }
  {
    alpha,
    beta,
    prior_alpha: alpha,
    prior_beta: beta,
    successes: 0,
    failures: 0,
    exposure: 0.0,
    label,
  }
}

///|
pub fn reliability_beta_update(
  posterior : ReliabilityBetaPosterior,
  successes : Int,
  failures : Int,
) -> ReliabilityBetaPosterior {
  if successes < 0 || failures < 0 {
    abort("observed counts must be non-negative")
  }
  {
    ..posterior,
    alpha: posterior.alpha + successes.to_double(),
    beta: posterior.beta + failures.to_double(),
    successes: posterior.successes + successes,
    failures: posterior.failures + failures,
  }
}

///|
pub fn reliability_beta_update_exposure(
  posterior : ReliabilityBetaPosterior,
  successes : Int,
  trials : Int,
) -> ReliabilityBetaPosterior {
  if trials < 0 || successes < 0 || successes > trials {
    abort("invalid Bernoulli exposure")
  }
  reliability_beta_update(posterior, successes, trials - successes)
}

///|
pub fn reliability_beta_mean(posterior : ReliabilityBetaPosterior) -> Double {
  posterior.alpha / (posterior.alpha + posterior.beta)
}

///|
pub fn reliability_beta_variance(
  posterior : ReliabilityBetaPosterior,
) -> Double {
  let total = posterior.alpha + posterior.beta
  posterior.alpha * posterior.beta / (total * total * (total + 1.0))
}

///|
pub fn reliability_beta_standard_deviation(
  posterior : ReliabilityBetaPosterior,
) -> Double {
  reliability_beta_variance(posterior).sqrt()
}

///|
pub fn reliability_beta_mode(posterior : ReliabilityBetaPosterior) -> Double {
  if posterior.alpha <= 1.0 || posterior.beta <= 1.0 {
    reliability_beta_mean(posterior)
  } else {
    (posterior.alpha - 1.0) / (posterior.alpha + posterior.beta - 2.0)
  }
}

///|
fn reliability_beta_log_density(
  posterior : ReliabilityBetaPosterior,
  value : Double,
) -> Double {
  if value <= 0.0 || value >= 1.0 {
    -1.0e300
  } else {
    (posterior.alpha - 1.0) * safe_log_probability(value) +
    (posterior.beta - 1.0) * safe_log_probability(1.0 - value) -
    (
      gamma_log(posterior.alpha) +
      gamma_log(posterior.beta) -
      gamma_log(posterior.alpha + posterior.beta)
    )
  }
}

///|
pub fn reliability_beta_density(
  posterior : ReliabilityBetaPosterior,
  value : Double,
) -> Double {
  if value <= 0.0 || value >= 1.0 {
    0.0
  } else {
    @math.exp(reliability_beta_log_density(posterior, value))
  }
}

///|
pub fn reliability_beta_cdf(
  posterior : ReliabilityBetaPosterior,
  value : Double,
) -> Double {
  if value <= 0.0 {
    0.0
  } else if value >= 1.0 {
    1.0
  } else {
    let steps = 400
    let step = value / steps.to_double()
    let mut total = 0.0
    for i in 0..<steps {
      let left = i.to_double() * step
      let right = left + step
      total += (
          reliability_beta_density(posterior, left + 1.0e-12) +
          reliability_beta_density(posterior, right)
        ) *
        step /
        2.0
    }
    total.min(1.0).max(0.0)
  }
}

///|
pub fn reliability_beta_quantile(
  posterior : ReliabilityBetaPosterior,
  probability : Double,
) -> Double {
  if probability <= 0.0 {
    0.0
  } else if probability >= 1.0 {
    1.0
  } else {
    let mut low = 0.0
    let mut high = 1.0
    for _ in 0..<70 {
      let middle = (low + high) / 2.0
      if reliability_beta_cdf(posterior, middle) < probability {
        low = middle
      } else {
        high = middle
      }
    }
    (low + high) / 2.0
  }
}

///|
pub fn reliability_beta_interval(
  posterior : ReliabilityBetaPosterior,
  confidence : Double,
) -> MetricEstimate {
  if confidence <= 0.0 || confidence >= 1.0 {
    abort("confidence must be in (0, 1)")
  }
  metric_estimate(
    estimate=reliability_beta_mean(posterior),
    lower=reliability_beta_quantile(posterior, (1.0 - confidence) / 2.0),
    upper=reliability_beta_quantile(posterior, (1.0 + confidence) / 2.0),
    confidence_level=confidence,
  )
}

///|
pub fn reliability_beta_predictive_success(
  posterior : ReliabilityBetaPosterior,
  trials : Int,
) -> Double {
  if trials < 0 {
    abort("trials must be non-negative")
  }
  reliability_beta_mean(posterior) * trials.to_double()
}

///|
pub fn reliability_beta_predictive_failure(
  posterior : ReliabilityBetaPosterior,
  trials : Int,
) -> Double {
  trials.to_double() - reliability_beta_predictive_success(posterior, trials)
}

///|
pub fn reliability_beta_predictive_probability(
  posterior : ReliabilityBetaPosterior,
  successes : Int,
  trials : Int,
) -> Double {
  if successes < 0 || trials < 0 || successes > trials {
    abort("invalid predictive count")
  }
  @math.exp(
    log_factorial(trials) -
    log_factorial(successes) -
    log_factorial(trials - successes) +
    gamma_log(posterior.alpha + successes.to_double()) +
    gamma_log(posterior.beta + (trials - successes).to_double()) -
    gamma_log(posterior.alpha + posterior.beta + trials.to_double()) -
    gamma_log(posterior.alpha) -
    gamma_log(posterior.beta) +
    gamma_log(posterior.alpha + posterior.beta),
  )
}

///|
pub fn reliability_beta_predictive_cdf(
  posterior : ReliabilityBetaPosterior,
  successes : Int,
  trials : Int,
) -> Double {
  if successes < 0 || trials < 0 || successes > trials {
    abort("invalid predictive CDF")
  }
  let mut result = 0.0
  for k in 0..<=successes {
    result += reliability_beta_predictive_probability(posterior, k, trials)
  }
  result.min(1.0)
}

///|
pub fn reliability_beta_posterior_strength(
  posterior : ReliabilityBetaPosterior,
) -> Double {
  posterior.alpha + posterior.beta
}

///|
pub fn reliability_beta_prior_weight(
  posterior : ReliabilityBetaPosterior,
) -> Double {
  (posterior.prior_alpha + posterior.prior_beta) /
  reliability_beta_posterior_strength(posterior)
}

///|
pub fn reliability_beta_data_weight(
  posterior : ReliabilityBetaPosterior,
) -> Double {
  1.0 - reliability_beta_prior_weight(posterior)
}

///|
pub fn reliability_beta_shrinkage(
  posterior : ReliabilityBetaPosterior,
) -> Double {
  reliability_beta_mean(posterior) -
  posterior.successes.to_double() /
  (posterior.successes + posterior.failures).to_double().max(1.0)
}

///|
pub fn reliability_beta_log_evidence(
  posterior : ReliabilityBetaPosterior,
) -> Double {
  gamma_log(posterior.alpha) +
  gamma_log(posterior.beta) -
  gamma_log(posterior.alpha + posterior.beta) -
  gamma_log(posterior.prior_alpha) -
  gamma_log(posterior.prior_beta) +
  gamma_log(posterior.prior_alpha + posterior.prior_beta)
}

///|
pub fn reliability_beta_information(
  posterior : ReliabilityBetaPosterior,
) -> Double {
  0.5 *
  @math.ln(
    1.0 + posterior.successes.to_double() + posterior.failures.to_double(),
  )
}

///|
pub struct ReliabilityGammaPosterior {
  shape : Double
  rate : Double
  prior_shape : Double
  prior_rate : Double
  events : Int
  exposure : Double
  label : String
}

///|
pub fn reliability_gamma_prior(
  shape : Double,
  rate : Double,
  label : String,
) -> ReliabilityGammaPosterior {
  if shape <= 0.0 || rate <= 0.0 {
    abort("gamma prior parameters must be positive")
  }
  {
    shape,
    rate,
    prior_shape: shape,
    prior_rate: rate,
    events: 0,
    exposure: 0.0,
    label,
  }
}

///|
pub fn reliability_gamma_update(
  posterior : ReliabilityGammaPosterior,
  events : Int,
  exposure : Double,
) -> ReliabilityGammaPosterior {
  if events < 0 || exposure < 0.0 {
    abort("invalid gamma update")
  }
  {
    ..posterior,
    shape: posterior.shape + events.to_double(),
    rate: posterior.rate + exposure,
    events: posterior.events + events,
    exposure: posterior.exposure + exposure,
  }
}

///|
pub fn reliability_gamma_mean(posterior : ReliabilityGammaPosterior) -> Double {
  posterior.shape / posterior.rate
}

///|
pub fn reliability_gamma_variance(
  posterior : ReliabilityGammaPosterior,
) -> Double {
  posterior.shape / (posterior.rate * posterior.rate)
}

///|
pub fn reliability_gamma_mode(posterior : ReliabilityGammaPosterior) -> Double {
  if posterior.shape <= 1.0 {
    0.0
  } else {
    (posterior.shape - 1.0) / posterior.rate
  }
}

///|
pub fn reliability_gamma_standard_deviation(
  posterior : ReliabilityGammaPosterior,
) -> Double {
  reliability_gamma_variance(posterior).sqrt()
}

///|
pub fn reliability_gamma_density(
  posterior : ReliabilityGammaPosterior,
  rate_value : Double,
) -> Double {
  if rate_value < 0.0 {
    0.0
  } else {
    @math.exp(
      posterior.shape * @math.ln(posterior.rate) +
      (posterior.shape - 1.0) * safe_log_probability(rate_value) -
      posterior.rate * rate_value -
      gamma_log(posterior.shape),
    )
  }
}

///|
pub fn reliability_gamma_cdf(
  posterior : ReliabilityGammaPosterior,
  rate_value : Double,
) -> Double {
  if rate_value <= 0.0 {
    0.0
  } else {
    regularized_gamma_p(posterior.shape, posterior.rate * rate_value)
  }
}

///|
pub fn reliability_gamma_quantile(
  posterior : ReliabilityGammaPosterior,
  probability : Double,
) -> Double {
  if probability <= 0.0 {
    0.0
  } else if probability >= 1.0 {
    1.0e300
  } else {
    let mut low = 0.0
    let mut high = reliability_gamma_mean(posterior) * 10.0 + 1.0
    for _ in 0..<80 {
      let middle = (low + high) / 2.0
      if reliability_gamma_cdf(posterior, middle) < probability {
        low = middle
      } else {
        high = middle
      }
    }
    (low + high) / 2.0
  }
}

///|
pub fn reliability_gamma_interval(
  posterior : ReliabilityGammaPosterior,
  confidence : Double,
) -> MetricEstimate {
  if confidence <= 0.0 || confidence >= 1.0 {
    abort("confidence must be in (0, 1)")
  }
  metric_estimate(
    estimate=reliability_gamma_mean(posterior),
    lower=reliability_gamma_quantile(posterior, (1.0 - confidence) / 2.0),
    upper=reliability_gamma_quantile(posterior, (1.0 + confidence) / 2.0),
    confidence_level=confidence,
  )
}

///|
pub fn reliability_gamma_predictive_failures(
  posterior : ReliabilityGammaPosterior,
  future_exposure : Double,
) -> Double {
  if future_exposure < 0.0 {
    abort("future exposure must be non-negative")
  }
  future_exposure * reliability_gamma_mean(posterior)
}

///|
pub fn reliability_gamma_predictive_probability_zero(
  posterior : ReliabilityGammaPosterior,
  future_exposure : Double,
) -> Double {
  if future_exposure < 0.0 {
    abort("future exposure must be non-negative")
  }
  @math.exp(
    posterior.shape *
    @math.ln(posterior.rate / (posterior.rate + future_exposure)),
  )
}

///|
pub fn reliability_gamma_predictive_probability_at_most(
  posterior : ReliabilityGammaPosterior,
  events : Int,
  future_exposure : Double,
) -> Double {
  if events < 0 || future_exposure < 0.0 {
    abort("invalid predictive event inputs")
  }
  let scale = future_exposure / (posterior.rate + future_exposure)
  let mut probability = 0.0
  for k in 0..<=events {
    probability += @math.exp(
      gamma_log(posterior.shape + k.to_double()) -
      gamma_log(posterior.shape) -
      gamma_log(k.to_double() + 1.0) +
      posterior.shape * @math.ln(1.0 - scale) +
      k.to_double() * safe_log_probability(scale),
    )
  }
  probability.min(1.0)
}

///|
pub fn reliability_gamma_rate_upper_bound(
  posterior : ReliabilityGammaPosterior,
  confidence : Double,
) -> Double {
  reliability_gamma_quantile(posterior, confidence)
}

///|
pub fn reliability_gamma_rate_lower_bound(
  posterior : ReliabilityGammaPosterior,
  confidence : Double,
) -> Double {
  reliability_gamma_quantile(posterior, 1.0 - confidence)
}

///|
pub fn reliability_gamma_failure_probability(
  posterior : ReliabilityGammaPosterior,
  horizon : Double,
) -> Double {
  if horizon < 0.0 {
    abort("horizon must be non-negative")
  }
  1.0 - reliability_gamma_predictive_probability_zero(posterior, horizon)
}

///|
pub fn reliability_gamma_survival_probability(
  posterior : ReliabilityGammaPosterior,
  horizon : Double,
) -> Double {
  1.0 - reliability_gamma_failure_probability(posterior, horizon)
}

///|
pub struct BayesianReliabilityCurvePoint {
  horizon : Double
  mean_reliability : Double
  lower_reliability : Double
  upper_reliability : Double
  failure_probability : Double
}

///|
pub fn bayesian_reliability_curve(
  posterior : ReliabilityGammaPosterior,
  horizons : Array[Double],
  confidence : Double,
) -> Array[BayesianReliabilityCurvePoint] {
  let upper_rate = reliability_gamma_rate_upper_bound(posterior, confidence)
  let lower_rate = reliability_gamma_rate_lower_bound(posterior, confidence)
  horizons.map(horizon => {
    let mean_rate = reliability_gamma_mean(posterior)
    {
      horizon,
      mean_reliability: @math.exp(-mean_rate * horizon),
      lower_reliability: @math.exp(-upper_rate * horizon),
      upper_reliability: @math.exp(-lower_rate * horizon),
      failure_probability: reliability_gamma_failure_probability(
        posterior, horizon,
      ),
    }
  })
}

///|
pub fn bayesian_curve_checksum(
  curve : Array[BayesianReliabilityCurvePoint],
) -> Double {
  curve.fold(init=0.0, (total, point) => {
    total +
    point.horizon +
    point.mean_reliability +
    point.lower_reliability +
    point.upper_reliability +
    point.failure_probability
  })
}

///|
pub fn bayesian_reliability_target_probability(
  posterior : ReliabilityGammaPosterior,
  horizon : Double,
  target_reliability : Double,
) -> Double {
  if target_reliability <= 0.0 || target_reliability >= 1.0 {
    abort("target reliability must be in (0, 1)")
  }
  let rate_limit = -@math.ln(target_reliability) / horizon.max(1.0e-12)
  reliability_gamma_cdf(posterior, rate_limit)
}

///|
pub fn bayesian_reliability_target_horizon(
  posterior : ReliabilityGammaPosterior,
  target_reliability : Double,
  confidence : Double,
) -> Double {
  if target_reliability <= 0.0 ||
    target_reliability >= 1.0 ||
    confidence <= 0.0 ||
    confidence >= 1.0 {
    abort("invalid target horizon inputs")
  }
  let rate = reliability_gamma_rate_upper_bound(posterior, confidence)
  -@math.ln(target_reliability) / rate.max(1.0e-300)
}

///|
pub fn bayesian_beta_to_metric(
  posterior : ReliabilityBetaPosterior,
  confidence : Double,
) -> MetricEstimate {
  reliability_beta_interval(posterior, confidence)
}

///|
pub fn bayesian_gamma_to_metric(
  posterior : ReliabilityGammaPosterior,
  confidence : Double,
) -> MetricEstimate {
  reliability_gamma_interval(posterior, confidence)
}

///|
pub fn bayesian_beta_checksum(posterior : ReliabilityBetaPosterior) -> Double {
  posterior.alpha +
  posterior.beta +
  posterior.prior_alpha +
  posterior.prior_beta +
  posterior.successes.to_double() +
  posterior.failures.to_double() +
  posterior.exposure
}

///|
pub fn bayesian_gamma_checksum(posterior : ReliabilityGammaPosterior) -> Double {
  posterior.shape +
  posterior.rate +
  posterior.prior_shape +
  posterior.prior_rate +
  posterior.events.to_double() +
  posterior.exposure
}

///|
pub fn bayesian_prior_from_mean_strength(
  mean_value : Double,
  strength : Double,
  label : String,
) -> ReliabilityBetaPosterior {
  if mean_value <= 0.0 || mean_value >= 1.0 || strength <= 0.0 {
    abort("invalid prior elicitation")
  }
  reliability_beta_prior(
    mean_value * strength,
    (1.0 - mean_value) * strength,
    label,
  )
}

///|
pub fn bayesian_rate_prior_from_mean_strength(
  mean_rate : Double,
  strength : Double,
  label : String,
) -> ReliabilityGammaPosterior {
  if mean_rate <= 0.0 || strength <= 0.0 {
    abort("invalid rate prior elicitation")
  }
  reliability_gamma_prior(strength, strength / mean_rate, label)
}

///|
pub fn bayesian_posterior_probability_above(
  posterior : ReliabilityBetaPosterior,
  threshold : Double,
) -> Double {
  1.0 - reliability_beta_cdf(posterior, threshold)
}

///|
pub fn bayesian_posterior_probability_below(
  posterior : ReliabilityBetaPosterior,
  threshold : Double,
) -> Double {
  reliability_beta_cdf(posterior, threshold)
}

///|
pub fn bayesian_posterior_decision(
  posterior : ReliabilityBetaPosterior,
  threshold : Double,
  probability : Double,
) -> String {
  let above = bayesian_posterior_probability_above(posterior, threshold)
  if above >= probability {
    "accept"
  } else if above <= 1.0 - probability {
    "reject"
  } else {
    "review"
  }
}

///|
pub fn bayesian_posterior_loss(
  posterior : ReliabilityBetaPosterior,
  target : Double,
  loss_below_target : Double,
  loss_above_target : Double,
) -> Double {
  if target <= 0.0 ||
    target >= 1.0 ||
    loss_below_target < 0.0 ||
    loss_above_target < 0.0 {
    abort("invalid posterior loss inputs")
  }
  let mean_value = reliability_beta_mean(posterior)
  if mean_value < target {
    loss_below_target * (target - mean_value)
  } else {
    loss_above_target * (mean_value - target)
  }
}

///|
pub fn bayesian_posterior_value_of_data(
  prior : ReliabilityBetaPosterior,
  posterior : ReliabilityBetaPosterior,
) -> Double {
  (reliability_beta_variance(prior) - reliability_beta_variance(posterior)).max(
    0.0,
  )
}

///|
pub fn bayesian_update_sequence(
  prior : ReliabilityBetaPosterior,
  successes : Array[Int],
  failures : Array[Int],
) -> Array[ReliabilityBetaPosterior] {
  if successes.length() != failures.length() {
    abort("update sequences must have same length")
  }
  let result : Array[ReliabilityBetaPosterior] = []
  let mut current = prior
  for i in 0..<successes.length() {
    current = reliability_beta_update(current, successes[i], failures[i])
    result.push(current)
  }
  result
}

///|
pub fn bayesian_mean_sequence(
  posteriors : Array[ReliabilityBetaPosterior],
) -> Array[Double] {
  posteriors.map(posterior => reliability_beta_mean(posterior))
}

///|
pub fn bayesian_uncertainty_sequence(
  posteriors : Array[ReliabilityBetaPosterior],
) -> Array[Double] {
  posteriors.map(posterior => reliability_beta_standard_deviation(posterior))
}

///|
pub fn bayesian_sequence_checksum(
  posteriors : Array[ReliabilityBetaPosterior],
) -> Double {
  posteriors.fold(init=0.0, (total, posterior) => {
    total + bayesian_beta_checksum(posterior)
  })
}
