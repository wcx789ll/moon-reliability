///|
/// Inverse-Gaussian lifetime distribution for degradation and first-passage models.
pub struct InverseGaussian {
  mean : Double
  shape : Double
}

///|
pub fn InverseGaussian::new(mean : Double, shape : Double) -> InverseGaussian {
  if mean <= 0.0 || shape <= 0.0 {
    abort("inverse-Gaussian parameters must be positive")
  }
  { mean, shape }
}

///|
pub fn InverseGaussian::pdf(self : InverseGaussian, time : Double) -> Double {
  if time <= 0.0 {
    0.0
  } else {
    (self.shape / (2.0 * @math.PI * time * time * time)).sqrt() *
    @math.exp(
      -self.shape *
      (time - self.mean) *
      (time - self.mean) /
      (2.0 * self.mean * self.mean * time),
    )
  }
}

///|
pub fn InverseGaussian::cdf(self : InverseGaussian, time : Double) -> Double {
  if time <= 0.0 {
    0.0
  } else {
    let first = standard_normal_cdf(
      (self.shape / time).sqrt() * (time / self.mean - 1.0),
    )
    let second = @math.exp(2.0 * self.shape / self.mean) *
      standard_normal_cdf(
        -(self.shape / time).sqrt() * (time / self.mean + 1.0),
      )
    (first + second).min(1.0)
  }
}

///|
pub fn InverseGaussian::survival(
  self : InverseGaussian,
  time : Double,
) -> Double {
  1.0 - self.cdf(time)
}

///|
pub fn InverseGaussian::hazard(self : InverseGaussian, time : Double) -> Double {
  let survival = self.survival(time)
  if survival <= 1.0e-300 {
    1.0e300
  } else {
    self.pdf(time) / survival
  }
}

///|
pub fn InverseGaussian::quantile(self : InverseGaussian, p : Double) -> Double {
  if p <= 0.0 || p >= 1.0 {
    abort("p must be in (0, 1)")
  }
  let mut lower = 0.0
  let mut upper = self.mean * 10.0
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
pub fn InverseGaussian::mean(self : InverseGaussian) -> Double {
  self.mean
}

///|
pub fn InverseGaussian::variance(self : InverseGaussian) -> Double {
  self.mean * self.mean * self.mean / self.shape
}

///|
pub fn inverse_gaussian_fit(values : Array[Double]) -> FitResult {
  let m = mean(values)
  let v = variance(values)
  let shape = m * m * m / v
  let model = InverseGaussian::new(m, shape)
  let mut ll = 0.0
  for value in values {
    ll += safe_log_probability(model.pdf(value))
  }
  let n = values.length()
  fit_result(
    distribution="inverse-gaussian",
    parameters=[m, shape],
    log_likelihood=ll,
    aic=aic(ll, 2),
    bic=bic(ll, 2, n),
    iterations=1,
    converged=true,
    standard_errors=[m / n.to_double().sqrt(), shape / n.to_double().sqrt()],
  )
}

///|
pub fn inverse_gaussian_mean_residual(
  model : InverseGaussian,
  age : Double,
) -> Double {
  if age <= 0.0 {
    model.mean
  } else {
    model.mean * model.survival(age) / model.survival(age).max(1.0e-300)
  }
}

///|
pub fn inverse_gaussian_reliability_margin(
  model : InverseGaussian,
  mission : Double,
  target : Double,
) -> Double {
  model.survival(mission) - target
}
