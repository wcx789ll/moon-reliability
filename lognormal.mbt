///|
/// Lognormal distribution for reliability modeling.
/// The parameters `mu` and `sigma` are the mean and standard deviation of the variable's natural logarithm.
pub struct Lognormal {
  mu : Double
  sigma : Double
}

///|
/// Create a new Lognormal distribution.
/// Panics if sigma is not strictly positive.
pub fn Lognormal::new(mu : Double, sigma : Double) -> Lognormal {
  if sigma <= 0.0 {
    abort("sigma must be strictly positive")
  }
  { mu, sigma }
}

///|
/// Probability density function (PDF) at time t.
pub fn Lognormal::pdf(self : Lognormal, t : Double) -> Double {
  if t <= 0.0 {
    0.0
  } else {
    let ln_t = @math.ln(t)
    let z = (ln_t - self.mu) / self.sigma
    1.0 / (t * self.sigma * (2.0 * @math.PI).sqrt()) * @math.exp(-0.5 * z * z)
  }
}

///|
/// Cumulative distribution function (CDF) at time t.
pub fn Lognormal::cdf(self : Lognormal, t : Double) -> Double {
  if t <= 0.0 {
    0.0
  } else {
    let z = (@math.ln(t) - self.mu) / self.sigma
    standard_normal_cdf(z)
  }
}

///|
/// Reliability function R(t) = 1 - CDF(t).
pub fn Lognormal::reliability(self : Lognormal, t : Double) -> Double {
  if t <= 0.0 {
    1.0
  } else {
    let z = (@math.ln(t) - self.mu) / self.sigma
    1.0 - standard_normal_cdf(z)
  }
}

///|
/// Mean Time Between Failures (MTBF).
pub fn Lognormal::mtbf(self : Lognormal) -> Double {
  @math.exp(self.mu + self.sigma * self.sigma / 2.0)
}

///|
/// Quantile function (inverse CDF).
pub fn Lognormal::quantile(self : Lognormal, p : Double) -> Double {
  if p <= 0.0 || p >= 1.0 {
    abort("p must be in (0, 1)")
  }
  let z = standard_normal_inv(p)
  @math.exp(self.mu + self.sigma * z)
}
