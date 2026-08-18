///|
/// Standard and non-standard Gaussian lifetime model.
pub struct Normal {
  mean : Double
  standard_deviation : Double
}

///|
pub fn Normal::new(mean : Double, standard_deviation : Double) -> Normal {
  if standard_deviation <= 0.0 {
    abort("standard_deviation must be strictly positive")
  }
  { mean, standard_deviation }
}

///|
pub fn Normal::pdf(self : Normal, x : Double) -> Double {
  let z = (x - self.mean) / self.standard_deviation
  @math.exp(-0.5 * z * z) / (self.standard_deviation * (2.0 * @math.PI).sqrt())
}

///|
pub fn Normal::log_pdf(self : Normal, x : Double) -> Double {
  let z = (x - self.mean) / self.standard_deviation
  -0.5 * z * z -
  @math.ln(self.standard_deviation) -
  0.5 * @math.ln(2.0 * @math.PI)
}

///|
pub fn Normal::cdf(self : Normal, x : Double) -> Double {
  standard_normal_cdf((x - self.mean) / self.standard_deviation)
}

///|
pub fn Normal::reliability(self : Normal, x : Double) -> Double {
  1.0 - self.cdf(x)
}

///|
pub fn Normal::quantile(self : Normal, p : Double) -> Double {
  if p <= 0.0 || p >= 1.0 {
    abort("p must be in (0, 1)")
  }
  self.mean + self.standard_deviation * standard_normal_inv(p)
}

///|
pub fn Normal::variance(self : Normal) -> Double {
  self.standard_deviation * self.standard_deviation
}

///|
pub fn Normal::hazard(self : Normal, x : Double) -> Double {
  let tail = self.reliability(x)
  if tail <= 1.0e-300 {
    1.0e300
  } else {
    self.pdf(x) / tail
  }
}

///|
pub fn Normal::entropy(self : Normal) -> Double {
  0.5 * @math.ln(2.0 * @math.PI * 2.718281828459045 * self.variance())
}

///|
pub fn Normal::standardize(self : Normal, x : Double) -> Double {
  (x - self.mean) / self.standard_deviation
}

///|
pub fn normal_log_likelihood(
  model : Normal,
  observations : Array[Double],
) -> Double {
  let mut result = 0.0
  for value in observations {
    result += model.log_pdf(value)
  }
  result
}

///|
pub fn normal_fit(observations : Array[Double]) -> FitResult {
  if observations.length() < 2 {
    abort("normal_fit requires at least two observations")
  }
  let m = mean(observations)
  let sd = variance(observations).sqrt()
  let model = Normal::new(m, sd)
  let ll = normal_log_likelihood(model, observations)
  let n = observations.length().to_double()
  fit_result(
    distribution="normal",
    parameters=[m, sd],
    log_likelihood=ll,
    aic=2.0 * 2.0 - 2.0 * ll,
    bic=2.0 * @math.ln(n) - 2.0 * ll,
    iterations=1,
    converged=true,
    standard_errors=[sd / n.sqrt(), sd / (2.0 * n).sqrt()],
  )
}
