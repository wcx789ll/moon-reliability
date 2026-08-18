///|
/// Log-logistic distribution, useful for bathtub-shaped hazard curves.
pub struct LogLogistic {
  scale : Double
  shape : Double
}

///|
pub fn LogLogistic::new(scale : Double, shape : Double) -> LogLogistic {
  if scale <= 0.0 || shape <= 0.0 {
    abort("scale and shape must be positive")
  }
  { scale, shape }
}

///|
pub fn LogLogistic::cdf(self : LogLogistic, t : Double) -> Double {
  if t <= 0.0 {
    0.0
  } else {
    1.0 / (1.0 + @math.pow(self.scale / t, self.shape))
  }
}

///|
pub fn LogLogistic::reliability(self : LogLogistic, t : Double) -> Double {
  1.0 - self.cdf(t)
}

///|
pub fn LogLogistic::pdf(self : LogLogistic, t : Double) -> Double {
  if t <= 0.0 {
    0.0
  } else {
    let z = @math.pow(t / self.scale, self.shape)
    self.shape /
    self.scale *
    @math.pow(t / self.scale, self.shape - 1.0) /
    ((1.0 + z) * (1.0 + z))
  }
}

///|
pub fn LogLogistic::hazard(self : LogLogistic, t : Double) -> Double {
  let survival = self.reliability(t)
  if survival <= 1.0e-300 {
    1.0e300
  } else {
    self.pdf(t) / survival
  }
}

///|
pub fn LogLogistic::quantile(self : LogLogistic, p : Double) -> Double {
  if p <= 0.0 || p >= 1.0 {
    abort("p must be in (0, 1)")
  }
  self.scale * @math.pow(p / (1.0 - p), 1.0 / self.shape)
}

///|
pub fn LogLogistic::mean(self : LogLogistic) -> Double {
  if self.shape <= 1.0 {
    1.0e300
  } else {
    self.scale * @math.PI / self.shape / @math.sin(@math.PI / self.shape)
  }
}

///|
pub fn LogLogistic::variance(self : LogLogistic) -> Double {
  if self.shape <= 2.0 {
    1.0e300
  } else {
    let a = @math.PI / self.shape
    self.scale *
    self.scale *
    (2.0 * a / @math.sin(2.0 * a) - a / @math.sin(a) * (a / @math.sin(a)))
  }
}

///|
pub fn loglogistic_fit(observations : Array[Double]) -> FitResult {
  if observations.length() < 2 {
    abort("loglogistic_fit requires at least two values")
  }
  let logs = observations.map(x => @math.ln(x))
  let scale = @math.exp(quantile(logs, 0.5))
  let spread = variance(logs).sqrt()
  let shape = @math.PI / (3.0.sqrt() * spread).max(0.05)
  let model = LogLogistic::new(scale, shape)
  let mut ll = 0.0
  for x in observations {
    ll += safe_log_probability(model.pdf(x))
  }
  let n = observations.length().to_double()
  fit_result(
    distribution="log-logistic",
    parameters=[scale, shape],
    log_likelihood=ll,
    aic=4.0 - 2.0 * ll,
    bic=2.0 * @math.ln(n) - 2.0 * ll,
    iterations=1,
    converged=true,
    standard_errors=[scale / n.sqrt(), shape / n.sqrt()],
  )
}
