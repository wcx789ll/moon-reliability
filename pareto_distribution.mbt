///|
/// Pareto type-I tail model for heavy-tailed lifetime and incident data.
pub struct Pareto {
  scale : Double
  shape : Double
}

///|
pub fn Pareto::new(scale : Double, shape : Double) -> Pareto {
  if scale <= 0.0 || shape <= 0.0 {
    abort("Pareto scale and shape must be positive")
  }
  { scale, shape }
}

///|
pub fn Pareto::cdf(self : Pareto, time : Double) -> Double {
  if time < self.scale {
    0.0
  } else {
    1.0 - @math.pow(self.scale / time, self.shape)
  }
}

///|
pub fn Pareto::survival(self : Pareto, time : Double) -> Double {
  if time < self.scale {
    1.0
  } else {
    @math.pow(self.scale / time, self.shape)
  }
}

///|
pub fn Pareto::pdf(self : Pareto, time : Double) -> Double {
  if time < self.scale {
    0.0
  } else {
    self.shape *
    @math.pow(self.scale, self.shape) /
    @math.pow(time, self.shape + 1.0)
  }
}

///|
pub fn Pareto::hazard(self : Pareto, time : Double) -> Double {
  if time < self.scale {
    0.0
  } else {
    self.shape / time
  }
}

///|
pub fn Pareto::quantile(self : Pareto, p : Double) -> Double {
  if p < 0.0 || p >= 1.0 {
    abort("p must be in [0, 1)")
  }
  self.scale / @math.pow(1.0 - p, 1.0 / self.shape)
}

///|
pub fn Pareto::mean(self : Pareto) -> Double {
  if self.shape <= 1.0 {
    1.0e300
  } else {
    self.shape * self.scale / (self.shape - 1.0)
  }
}

///|
pub fn Pareto::variance(self : Pareto) -> Double {
  if self.shape <= 2.0 {
    1.0e300
  } else {
    self.scale *
    self.scale *
    self.shape /
    ((self.shape - 1.0) * (self.shape - 1.0) * (self.shape - 2.0))
  }
}

///|
pub fn Pareto::conditional_mean(self : Pareto, age : Double) -> Double {
  if age < self.scale {
    self.mean()
  } else {
    self.shape * age / (self.shape - 1.0)
  }
}

///|
pub fn pareto_fit(values : Array[Double]) -> FitResult {
  let scale = min_value(values)
  let shape = values.length().to_double() /
    values.fold(init=0.0, (sum, value) => sum + @math.ln(value / scale))
  let model = Pareto::new(scale, shape)
  let mut ll = 0.0
  for value in values {
    ll += safe_log_probability(model.pdf(value))
  }
  let n = values.length()
  fit_result(
    distribution="pareto",
    parameters=[scale, shape],
    log_likelihood=ll,
    aic=aic(ll, 2),
    bic=bic(ll, 2, n),
    iterations=1,
    converged=true,
    standard_errors=[scale / n.to_double().sqrt(), shape / n.to_double().sqrt()],
  )
}

///|
pub fn tail_probability(model : Pareto, threshold : Double) -> Double {
  model.survival(threshold)
}

///|
pub fn extreme_quantile(model : Pareto, return_period : Double) -> Double {
  if return_period <= 1.0 {
    abort("return period must exceed one")
  }
  model.quantile(1.0 - 1.0 / return_period)
}
