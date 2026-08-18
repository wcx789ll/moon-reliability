///|
/// Gompertz distribution for ageing populations and wear-out dominated assets.
pub struct Gompertz {
  scale : Double
  growth : Double
}

///|
pub fn Gompertz::new(scale : Double, growth : Double) -> Gompertz {
  if scale <= 0.0 || growth <= 0.0 {
    abort("scale and growth must be positive")
  }
  { scale, growth }
}

///|
pub fn Gompertz::cum_hazard(self : Gompertz, t : Double) -> Double {
  if t <= 0.0 {
    0.0
  } else {
    self.scale * @math.expm1(self.growth * t)
  }
}

///|
pub fn Gompertz::reliability(self : Gompertz, t : Double) -> Double {
  @math.exp(-self.cum_hazard(t))
}

///|
pub fn Gompertz::cdf(self : Gompertz, t : Double) -> Double {
  1.0 - self.reliability(t)
}

///|
pub fn Gompertz::hazard(self : Gompertz, t : Double) -> Double {
  self.scale * self.growth * @math.exp(self.growth * t)
}

///|
pub fn Gompertz::pdf(self : Gompertz, t : Double) -> Double {
  if t < 0.0 {
    0.0
  } else {
    self.hazard(t) * self.reliability(t)
  }
}

///|
pub fn Gompertz::quantile(self : Gompertz, p : Double) -> Double {
  if p < 0.0 || p >= 1.0 {
    abort("p must be in [0, 1)")
  }
  @math.ln(1.0 - @math.ln(1.0 - p) / self.scale) / self.growth
}

///|
pub fn Gompertz::mean(self : Gompertz) -> Double {
  let mut total = 0.0
  let limit = self.quantile(1.0 - 1.0e-12)
  let step = limit / 400.0
  for i in 0..<400 {
    let x0 = i.to_double() * step
    let x1 = x0 + step
    total += (
        self.reliability(x0) +
        4.0 * self.reliability((x0 + x1) / 2.0) +
        self.reliability(x1)
      ) *
      step /
      6.0
  }
  total
}

///|
pub fn gompertz_fit(observations : Array[Double]) -> FitResult {
  if observations.length() < 3 {
    abort("gompertz_fit requires at least three values")
  }
  let logs = observations.map(x => @math.ln(1.0 + x))
  let growth = 1.0 / variance(logs).sqrt()
  let scale = 1.0 / (mean(observations) + 1.0)
  let model = Gompertz::new(scale, growth)
  let mut ll = 0.0
  for x in observations {
    ll += safe_log_probability(model.pdf(x))
  }
  let n = observations.length().to_double()
  fit_result(
    distribution="gompertz",
    parameters=[scale, growth],
    log_likelihood=ll,
    aic=4.0 - 2.0 * ll,
    bic=2.0 * @math.ln(n) - 2.0 * ll,
    iterations=1,
    converged=true,
    standard_errors=[scale / n.sqrt(), growth / n.sqrt()],
  )
}
