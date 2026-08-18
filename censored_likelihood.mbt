///|
/// A common model interface for censored likelihood calculations.
pub(all) enum ReliabilityModel {
  ExponentialModel(Exponential)
  WeibullModel(Weibull)
  LognormalModel(Lognormal)
  GammaModel(GammaDistribution)
  LogLogisticModel(LogLogistic)
}

///|
pub fn ReliabilityModel::cdf(self : ReliabilityModel, time : Double) -> Double {
  match self {
    ExponentialModel(model) => model.cdf(time)
    WeibullModel(model) => model.cdf(time)
    LognormalModel(model) => model.cdf(time)
    GammaModel(model) => model.cdf(time)
    LogLogisticModel(model) => model.cdf(time)
  }
}

///|
pub fn ReliabilityModel::survival(
  self : ReliabilityModel,
  time : Double,
) -> Double {
  match self {
    ExponentialModel(model) => model.reliability(time)
    WeibullModel(model) => model.reliability(time)
    LognormalModel(model) => model.reliability(time)
    GammaModel(model) => model.reliability(time)
    LogLogisticModel(model) => model.reliability(time)
  }
}

///|
pub fn ReliabilityModel::pdf(self : ReliabilityModel, time : Double) -> Double {
  match self {
    ExponentialModel(model) => model.pdf(time)
    WeibullModel(model) => model.pdf(time)
    LognormalModel(model) => model.pdf(time)
    GammaModel(model) => model.pdf(time)
    LogLogisticModel(model) => model.pdf(time)
  }
}

///|
pub fn ReliabilityModel::log_likelihood(
  self : ReliabilityModel,
  records : Array[LifeObservation],
) -> Double {
  let mut result = 0.0
  for record in records {
    let contribution = match record.status {
      Failed => safe_log_probability(self.pdf(record.time))
      RightCensored => safe_log_probability(self.survival(record.time))
      LeftCensored => safe_log_probability(self.cdf(record.time))
      IntervalCensored => safe_log_probability(self.cdf(record.time))
    }
    result += record.weight * contribution
  }
  result
}

///|
pub fn censored_log_likelihood(
  model : ReliabilityModel,
  records : Array[LifeObservation],
) -> Double {
  model.log_likelihood(records)
}

///|
pub fn aic(log_likelihood : Double, parameter_count : Int) -> Double {
  2.0 * parameter_count.to_double() - 2.0 * log_likelihood
}

///|
pub fn bic(
  log_likelihood : Double,
  parameter_count : Int,
  sample_size : Int,
) -> Double {
  2.0 * parameter_count.to_double() -
  2.0 * log_likelihood +
  parameter_count.to_double() * @math.ln(sample_size.to_double())
}

///|
pub fn observed_event_count(records : Array[LifeObservation]) -> Int {
  records.fold(init=0, (count, record) => {
    if record.is_failure() {
      count + 1
    } else {
      count
    }
  })
}

///|
pub fn total_exposure(records : Array[LifeObservation]) -> Double {
  records.fold(init=0.0, (total, record) => total + record.weight * record.time)
}

///|
pub fn exponential_fit_censored(records : Array[LifeObservation]) -> FitResult {
  if records.is_empty() {
    abort("exponential_fit_censored requires records")
  }
  let events = observed_event_count(records)
  if events == 0 {
    abort("at least one failure is required")
  }
  let exposure = total_exposure(records)
  let lambda = events.to_double() / exposure
  let model = Exponential::new(lambda)
  let ll = model_log_likelihood(model, records)
  let n = records.length()
  let standard_error = lambda / events.to_double().sqrt()
  fit_result(
    distribution="exponential-censored",
    parameters=[lambda],
    log_likelihood=ll,
    aic=aic(ll, 1),
    bic=bic(ll, 1, n),
    iterations=1,
    converged=true,
    standard_errors=[standard_error],
  )
}

///|
fn model_log_likelihood(
  model : Exponential,
  records : Array[LifeObservation],
) -> Double {
  ReliabilityModel::ExponentialModel(model).log_likelihood(records)
}

///|
/// Estimate Weibull shape and scale with a bounded Newton update on the
/// profile likelihood. Right-censored records contribute exposure to the
/// survival term and failures contribute the density term.
pub fn weibull_fit_censored(records : Array[LifeObservation]) -> FitResult {
  if records.is_empty() {
    abort("weibull_fit_censored requires records")
  }
  let events = observed_event_count(records)
  if events == 0 {
    abort("at least one failure is required")
  }
  let mut shape = 1.0
  let mut scale = total_exposure(records) / events.to_double()
  let mut converged = false
  let mut iterations = 0
  for _ in 0..<100 {
    let gradient = weibull_shape_gradient(shape, scale, records)
    let curvature = weibull_shape_curvature(shape, scale, records)
    if curvature.abs() < 1.0e-12 {
      break
    }
    let next = (shape - gradient / curvature).max(0.05).min(20.0)
    scale = weibull_profile_scale(next, records)
    iterations += 1
    if (next - shape).abs() < 1.0e-8 {
      shape = next
      converged = true
      break
    }
    shape = next
  }
  let model = Weibull::new(scale, shape)
  let ll = ReliabilityModel::WeibullModel(model).log_likelihood(records)
  let n = records.length()
  fit_result(
    distribution="weibull-censored",
    parameters=[scale, shape],
    log_likelihood=ll,
    aic=aic(ll, 2),
    bic=bic(ll, 2, n),
    iterations~,
    converged~,
    standard_errors=[scale / n.to_double().sqrt(), shape / n.to_double().sqrt()],
  )
}

///|
fn weibull_profile_scale(
  shape : Double,
  records : Array[LifeObservation],
) -> Double {
  let mut weighted_power = 0.0
  let mut failure_weight = 0.0
  for record in records {
    weighted_power += record.weight * @math.pow(record.time, shape)
    if record.is_failure() {
      failure_weight += record.weight
    }
  }
  @math.pow(weighted_power / failure_weight, 1.0 / shape)
}

///|
fn weibull_shape_gradient(
  shape : Double,
  scale : Double,
  records : Array[LifeObservation],
) -> Double {
  let mut value = 0.0
  for record in records {
    let ratio = record.time / scale
    let power = @math.pow(ratio, shape)
    let event_term = if record.is_failure() {
      1.0 / shape + @math.ln(ratio)
    } else {
      0.0
    }
    value += record.weight * (event_term - power * @math.ln(ratio))
  }
  value
}

///|
fn weibull_shape_curvature(
  shape : Double,
  scale : Double,
  records : Array[LifeObservation],
) -> Double {
  let mut value = 0.0
  for record in records {
    let log_ratio = @math.ln(record.time / scale)
    let power = @math.pow(record.time / scale, shape)
    let event_term = if record.is_failure() {
      -1.0 / (shape * shape)
    } else {
      0.0
    }
    value += record.weight * (event_term - power * log_ratio * log_ratio)
  }
  value
}

///|
pub fn lognormal_fit_censored(records : Array[LifeObservation]) -> FitResult {
  if records.is_empty() {
    abort("lognormal_fit_censored requires records")
  }
  let failures = records.filter_map(record => {
    if record.is_failure() {
      Some(@math.ln(record.time))
    } else {
      None
    }
  })
  if failures.length() < 2 {
    abort("at least two failures are required")
  }
  let mu = mean(failures)
  let sigma = variance(failures).sqrt()
  let model = Lognormal::new(mu, sigma.max(0.01))
  let ll = ReliabilityModel::LognormalModel(model).log_likelihood(records)
  let n = records.length()
  fit_result(
    distribution="lognormal-censored",
    parameters=[mu, sigma],
    log_likelihood=ll,
    aic=aic(ll, 2),
    bic=bic(ll, 2, n),
    iterations=1,
    converged=true,
    standard_errors=[
      sigma / n.to_double().sqrt(),
      sigma / (2.0 * n.to_double()).sqrt(),
    ],
  )
}
