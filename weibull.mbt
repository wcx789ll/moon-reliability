///|
/// Weibull distribution for reliability modeling.
/// The parameter `scale` ($\lambda$) is the characteristic life.
/// The parameter `shape` ($k$) is the shape parameter (slope).
pub struct Weibull {
  scale : Double
  shape : Double
}

///|
/// Create a new Weibull distribution.
/// Panics if scale or shape are not strictly positive.
pub fn Weibull::new(scale : Double, shape : Double) -> Weibull {
  if scale <= 0.0 || shape <= 0.0 {
    abort("scale and shape must be strictly positive")
  }
  { scale, shape }
}

///|
/// Probability density function (PDF) at time t.
pub fn Weibull::pdf(self : Weibull, t : Double) -> Double {
  if t < 0.0 {
    0.0
  } else if t == 0.0 && self.shape < 1.0 {
    // PDF approaches infinity as t -> 0 when shape < 1
    // Usually represented as infinity or NaN in IEEE-754, but let's return a very large value or let it compute.
    let t_safe = 1.0e-150
    self.shape /
    self.scale *
    @math.pow(t_safe / self.scale, self.shape - 1.0) *
    @math.exp(-@math.pow(t_safe / self.scale, self.shape))
  } else {
    self.shape /
    self.scale *
    @math.pow(t / self.scale, self.shape - 1.0) *
    @math.exp(-@math.pow(t / self.scale, self.shape))
  }
}

///|
/// Cumulative distribution function (CDF) at time t.
pub fn Weibull::cdf(self : Weibull, t : Double) -> Double {
  if t < 0.0 {
    0.0
  } else {
    1.0 - @math.exp(-@math.pow(t / self.scale, self.shape))
  }
}

///|
/// Reliability function R(t) = 1 - CDF(t), probability of surviving past time t.
pub fn Weibull::reliability(self : Weibull, t : Double) -> Double {
  if t < 0.0 {
    1.0
  } else {
    @math.exp(-@math.pow(t / self.scale, self.shape))
  }
}

///|
/// Failure rate function (Hazard rate) at time t.
pub fn Weibull::failure_rate(self : Weibull, t : Double) -> Double {
  if t < 0.0 {
    0.0
  } else {
    self.shape / self.scale * @math.pow(t / self.scale, self.shape - 1.0)
  }
}

///|
/// Mean Time Between Failures (MTBF) / Expected Value.
pub fn Weibull::mtbf(self : Weibull) -> Double {
  self.scale * gamma(1.0 + 1.0 / self.shape)
}

///|
/// Quantile function (inverse CDF). Returns the time at which cumulative probability is p.
pub fn Weibull::quantile(self : Weibull, p : Double) -> Double {
  if p < 0.0 || p >= 1.0 {
    abort("p must be in [0, 1)")
  }
  self.scale * @math.pow(-@math.ln(1.0 - p), 1.0 / self.shape)
}
