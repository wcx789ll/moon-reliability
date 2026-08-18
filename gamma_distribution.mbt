///|
/// Gamma lifetime distribution parameterized by shape and rate.
pub struct GammaDistribution {
  shape : Double
  rate : Double
}

///|
pub fn GammaDistribution::new(
  shape : Double,
  rate : Double,
) -> GammaDistribution {
  if shape <= 0.0 || rate <= 0.0 {
    abort("shape and rate must be strictly positive")
  }
  { shape, rate }
}

///|
pub fn GammaDistribution::log_pdf(
  self : GammaDistribution,
  x : Double,
) -> Double {
  if x <= 0.0 {
    -1.0e300
  } else {
    (self.shape - 1.0) * @math.ln(x) -
    self.rate * x -
    gamma_log(self.shape) +
    self.shape * @math.ln(self.rate)
  }
}

///|
pub fn GammaDistribution::pdf(self : GammaDistribution, x : Double) -> Double {
  if x <= 0.0 {
    0.0
  } else {
    @math.exp(self.log_pdf(x))
  }
}

///|
pub fn GammaDistribution::cdf(self : GammaDistribution, x : Double) -> Double {
  if x <= 0.0 {
    0.0
  } else {
    regularized_gamma_p(self.shape, self.rate * x)
  }
}

///|
pub fn GammaDistribution::reliability(
  self : GammaDistribution,
  x : Double,
) -> Double {
  1.0 - self.cdf(x)
}

///|
pub fn GammaDistribution::quantile(
  self : GammaDistribution,
  p : Double,
) -> Double {
  if p <= 0.0 || p >= 1.0 {
    abort("p must be in (0, 1)")
  }
  let mut lower = 0.0
  let mut upper = (self.shape + 10.0 * self.shape.sqrt() + 10.0) / self.rate
  while self.cdf(upper) < p {
    upper *= 2.0
  }
  for _ in 0..<80 {
    let middle = (lower + upper) / 2.0
    if self.cdf(middle) < p {
      lower = middle
    } else {
      upper = middle
    }
  }
  (lower + upper) / 2.0
}

///|
pub fn GammaDistribution::mean(self : GammaDistribution) -> Double {
  self.shape / self.rate
}

///|
pub fn GammaDistribution::variance(self : GammaDistribution) -> Double {
  self.shape / (self.rate * self.rate)
}

///|
pub fn GammaDistribution::failure_rate(
  self : GammaDistribution,
  x : Double,
) -> Double {
  let survival = self.reliability(x)
  if survival <= 1.0e-300 {
    1.0e300
  } else {
    self.pdf(x) / survival
  }
}

///|
pub fn gamma_log(z : Double) -> Double {
  @math.ln(gamma(z).abs())
}

///|
/// Lower regularized incomplete gamma using a power series for x < a+1.
pub fn regularized_gamma_p(a : Double, x : Double) -> Double {
  if a <= 0.0 || x < 0.0 {
    abort("invalid incomplete gamma arguments")
  }
  if x == 0.0 {
    return 0.0
  }
  if x > a + 1.0 {
    return 1.0 - regularized_gamma_q(a, x)
  }
  let mut term = 1.0 / a
  let mut sum = term
  let mut n = 1.0
  while n < 1000.0 {
    term *= x / (a + n)
    sum += term
    if term.abs() < sum.abs() * 1.0e-14 {
      break
    }
    n += 1.0
  }
  sum * @math.exp(-x + a * @math.ln(x) - gamma_log(a))
}

///|
/// Upper regularized incomplete gamma using a continued fraction.
pub fn regularized_gamma_q(a : Double, x : Double) -> Double {
  if a <= 0.0 || x <= 0.0 {
    return 1.0
  }
  let tiny = 1.0e-300
  let mut b = x + 1.0 - a
  let mut c = 1.0 / tiny
  let mut d = 1.0 / b
  let mut h = d
  for i in 1..<=1000 {
    let ii = i.to_double()
    let an = -ii * (ii - a)
    b += 2.0
    d = an * d + b
    if d.abs() < tiny {
      d = tiny
    }
    c = b + an / c
    if c.abs() < tiny {
      c = tiny
    }
    d = 1.0 / d
    let delta = d * c
    h *= delta
    if (delta - 1.0).abs() < 1.0e-14 {
      break
    }
  }
  @math.exp(-x + a * @math.ln(x) - gamma_log(a)) * h
}

///|
pub fn gamma_fit(observations : Array[Double]) -> FitResult {
  if observations.length() < 2 {
    abort("gamma_fit requires at least two values")
  }
  let m = mean(observations)
  let v = variance(observations)
  let initial = m * m / v
  let mut shape = initial.max(0.05)
  let mut iterations = 0
  for _ in 0..<80 {
    let mean_log = mean(observations.map(x => @math.ln(x)))
    let equation = @math.ln(shape) - digamma(shape) - @math.ln(m) + mean_log
    let derivative = 1.0 / shape - trigamma(shape)
    let next = (shape - equation / derivative).max(0.01)
    iterations += 1
    if (next - shape).abs() < 1.0e-9 {
      shape = next
      break
    }
    shape = next
  }
  let rate = shape / m
  let model = GammaDistribution::new(shape, rate)
  let ll = observations.fold(init=0.0, (total, x) => total + model.log_pdf(x))
  let n = observations.length().to_double()
  fit_result(
    distribution="gamma",
    parameters=[shape, rate],
    log_likelihood=ll,
    aic=4.0 - 2.0 * ll,
    bic=2.0 * @math.ln(n) - 2.0 * ll,
    iterations~,
    converged=true,
    standard_errors=[shape / n.sqrt(), rate / n.sqrt()],
  )
}

///|
pub fn digamma(x : Double) -> Double {
  let mut y = x
  let mut result = 0.0
  while y < 8.0 {
    result -= 1.0 / y
    y += 1.0
  }
  let inv = 1.0 / y
  let inv2 = inv * inv
  result +
  @math.ln(y) -
  0.5 * inv -
  inv2 * (1.0 / 12.0 - inv2 * (1.0 / 120.0 - inv2 / 252.0))
}

///|
pub fn trigamma(x : Double) -> Double {
  let mut y = x
  let mut result = 0.0
  while y < 8.0 {
    result += 1.0 / (y * y)
    y += 1.0
  }
  let inv = 1.0 / y
  let inv2 = inv * inv
  result + inv + inv2 / 2.0 + inv2 * inv / 6.0 - inv2 * inv2 * inv / 30.0
}
