///|
/// Exponential distribution for reliability and lifetime analysis.
/// The parameter `lambda` is the failure rate (inverse of scale/MTBF).
pub struct Exponential {
  lambda : Double
}

///|
/// Create a new Exponential distribution.
/// Panics if lambda is not strictly positive.
pub fn Exponential::new(lambda : Double) -> Exponential {
  if lambda <= 0.0 {
    abort("lambda must be strictly positive")
  }
  { lambda, }
}

///|
/// Probability density function (PDF) at time t.
pub fn Exponential::pdf(self : Exponential, t : Double) -> Double {
  if t < 0.0 {
    0.0
  } else {
    self.lambda * @math.exp(-self.lambda * t)
  }
}

///|
/// Cumulative distribution function (CDF) at time t (probability of failure before t).
pub fn Exponential::cdf(self : Exponential, t : Double) -> Double {
  if t < 0.0 {
    0.0
  } else {
    1.0 - @math.exp(-self.lambda * t)
  }
}

///|
/// Reliability function R(t) = 1 - CDF(t), probability of surviving past time t.
pub fn Exponential::reliability(self : Exponential, t : Double) -> Double {
  if t < 0.0 {
    1.0
  } else {
    @math.exp(-self.lambda * t)
  }
}

///|
/// Mean Time Between Failures (MTBF).
pub fn Exponential::mtbf(self : Exponential) -> Double {
  1.0 / self.lambda
}

///|
/// Failure rate function (Hazard rate), constant for Exponential.
pub fn Exponential::failure_rate(self : Exponential, _t : Double) -> Double {
  self.lambda
}

///|
/// Quantile function (inverse CDF). Returns the time at which cumulative probability is p.
pub fn Exponential::quantile(self : Exponential, p : Double) -> Double {
  if p < 0.0 || p >= 1.0 {
    abort("p must be in [0, 1)")
  }
  -@math.ln(1.0 - p) / self.lambda
}
