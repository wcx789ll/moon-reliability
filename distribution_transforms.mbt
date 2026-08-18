///|
/// Transform an ordinary lifetime model into a truncated model.
pub struct TruncatedModel {
  base : ReliabilityModel
  lower : Double
  upper : Double
  normalization : Double
}

///|
pub fn truncated_model(
  base~ : ReliabilityModel,
  lower~ : Double,
  upper~ : Double,
) -> TruncatedModel {
  if lower < 0.0 || upper <= lower {
    abort("invalid truncation bounds")
  }
  let normalization = base.cdf(upper) - base.cdf(lower)
  if normalization <= 0.0 {
    abort("empty truncation interval")
  }
  { base, lower, upper, normalization }
}

///|
pub fn TruncatedModel::cdf(self : TruncatedModel, time : Double) -> Double {
  if time <= self.lower {
    0.0
  } else if time >= self.upper {
    1.0
  } else {
    (self.base.cdf(time) - self.base.cdf(self.lower)) / self.normalization
  }
}

///|
pub fn TruncatedModel::reliability(
  self : TruncatedModel,
  time : Double,
) -> Double {
  1.0 - self.cdf(time)
}

///|
pub fn TruncatedModel::pdf(self : TruncatedModel, time : Double) -> Double {
  if time < self.lower || time > self.upper {
    0.0
  } else {
    self.base.pdf(time) / self.normalization
  }
}

///|
pub fn TruncatedModel::quantile(self : TruncatedModel, p : Double) -> Double {
  if p <= 0.0 || p >= 1.0 {
    abort("p must be in (0, 1)")
  }
  model_quantile(self.base, self.base.cdf(self.lower) + p * self.normalization)
}

///|
pub fn model_from_fit(fit : FitResult) -> ReliabilityModel {
  if fit.distribution.contains("exponential") {
    ExponentialModel(Exponential::new(fit.parameters[0]))
  } else if fit.distribution.contains("weibull") {
    WeibullModel(Weibull::new(fit.parameters[0], fit.parameters[1]))
  } else if fit.distribution.contains("lognormal") {
    LognormalModel(Lognormal::new(fit.parameters[0], fit.parameters[1]))
  } else if fit.distribution.contains("gamma") {
    GammaModel(GammaDistribution::new(fit.parameters[0], fit.parameters[1]))
  } else {
    abort("unsupported fit distribution")
  }
}

///|
pub fn mixture_survival(
  models : Array[ReliabilityModel],
  weights : Array[Double],
  time : Double,
) -> Double {
  if models.length() != weights.length() || models.is_empty() {
    abort("mixture arrays mismatch")
  }
  let total = weights.fold(init=0.0, (sum, weight) => sum + weight)
  let mut result = 0.0
  for i in 0..<models.length() {
    result += weights[i] / total * models[i].survival(time)
  }
  result
}

///|
pub fn mixture_cdf(
  models : Array[ReliabilityModel],
  weights : Array[Double],
  time : Double,
) -> Double {
  1.0 - mixture_survival(models, weights, time)
}

///|
pub fn mixture_quantile(
  models : Array[ReliabilityModel],
  weights : Array[Double],
  p : Double,
  upper : Double,
) -> Double {
  let mut lower = 0.0
  let mut high = upper
  for _ in 0..<80 {
    let middle = (lower + high) / 2.0
    if mixture_cdf(models, weights, middle) < p {
      lower = middle
    } else {
      high = middle
    }
  }
  (lower + high) / 2.0
}

///|
pub fn quantile_spacing(
  model : ReliabilityModel,
  probabilities : Array[Double],
) -> Array[Double] {
  probabilities.map(p => model_quantile(model, p))
}
