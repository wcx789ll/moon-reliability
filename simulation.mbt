///|
/// Small deterministic pseudo-random generator for reproducible reliability
/// experiments. It is not intended for cryptography.
pub struct RandomState {
  mut state : Int
}

///|
pub fn RandomState::new(seed : Int) -> RandomState {
  let normalized = if seed <= 0 { 1 } else { seed % 2147483647 }
  { state: normalized }
}

///|
pub fn RandomState::next_int(self : RandomState) -> Int {
  let quotient = self.state / 44488
  let remainder = self.state % 44488
  let next = 40014 * remainder - 3399 * quotient
  self.state = if next > 0 { next } else { next + 2147483563 }
  self.state
}

///|
pub fn RandomState::uniform(self : RandomState) -> Double {
  self.next_int().to_double() / 2147483647.0
}

///|
pub fn RandomState::normal(self : RandomState) -> Double {
  let first = self.uniform().max(1.0e-12)
  let second = self.uniform()
  (-2.0 * @math.ln(first)).sqrt() * @math.cos(2.0 * @math.PI * second)
}

///|
pub fn RandomState::exponential(self : RandomState, lambda : Double) -> Double {
  if lambda <= 0.0 {
    abort("lambda must be positive")
  }
  -@math.ln((1.0 - self.uniform()).max(1.0e-12)) / lambda
}

///|
pub fn RandomState::weibull(
  self : RandomState,
  scale : Double,
  shape : Double,
) -> Double {
  if scale <= 0.0 || shape <= 0.0 {
    abort("scale and shape must be positive")
  }
  scale * @math.pow(-@math.ln((1.0 - self.uniform()).max(1.0e-12)), 1.0 / shape)
}

///|
pub fn RandomState::lognormal(
  self : RandomState,
  mu : Double,
  sigma : Double,
) -> Double {
  if sigma <= 0.0 {
    abort("sigma must be positive")
  }
  @math.exp(mu + sigma * self.normal())
}

///|
pub fn sample_exponential(
  seed : Int,
  lambda : Double,
  count : Int,
) -> Array[Double] {
  if count < 0 {
    abort("count must be non-negative")
  }
  let state = RandomState::new(seed)
  let result : Array[Double] = []
  for _ in 0..<count {
    result.push(state.exponential(lambda))
  }
  result
}

///|
pub fn sample_weibull(
  seed : Int,
  scale : Double,
  shape : Double,
  count : Int,
) -> Array[Double] {
  if count < 0 {
    abort("count must be non-negative")
  }
  let state = RandomState::new(seed)
  let result : Array[Double] = []
  for _ in 0..<count {
    result.push(state.weibull(scale, shape))
  }
  result
}

///|
pub fn sample_lognormal(
  seed : Int,
  mu : Double,
  sigma : Double,
  count : Int,
) -> Array[Double] {
  if count < 0 {
    abort("count must be non-negative")
  }
  let state = RandomState::new(seed)
  let result : Array[Double] = []
  for _ in 0..<count {
    result.push(state.lognormal(mu, sigma))
  }
  result
}

///|
pub fn simulate_exponential_records(
  seed : Int,
  lambda : Double,
  count : Int,
  censor_time : Double,
) -> Array[LifeObservation] {
  let state = RandomState::new(seed)
  let result : Array[LifeObservation] = []
  for _ in 0..<count {
    let life = state.exponential(lambda)
    result.push(
      if life <= censor_time {
        failure(life)
      } else {
        right_censored(censor_time)
      },
    )
  }
  result
}

///|
pub fn simulate_weibull_records(
  seed : Int,
  scale : Double,
  shape : Double,
  count : Int,
  censor_time : Double,
) -> Array[LifeObservation] {
  let state = RandomState::new(seed)
  let result : Array[LifeObservation] = []
  for _ in 0..<count {
    let life = state.weibull(scale, shape)
    result.push(
      if life <= censor_time {
        failure(life)
      } else {
        right_censored(censor_time)
      },
    )
  }
  result
}

///|
pub fn monte_carlo_reliability(
  seed : Int,
  model : ReliabilityModel,
  time : Double,
  replications : Int,
) -> MetricEstimate {
  if replications <= 1 {
    abort("replications must exceed one")
  }
  let state = RandomState::new(seed)
  let mut successes = 0.0
  for _ in 0..<replications {
    let life = match model {
      ExponentialModel(value) => state.exponential(value.lambda)
      WeibullModel(value) => state.weibull(value.scale, value.shape)
      LognormalModel(value) => state.lognormal(value.mu, value.sigma)
      GammaModel(value) => value.quantile(state.uniform().max(1.0e-9))
      LogLogisticModel(value) => value.quantile(state.uniform().max(1.0e-9))
    }
    if life > time {
      successes += 1.0
    }
  }
  let estimate = successes / replications.to_double()
  let error = 1.96 *
    (estimate * (1.0 - estimate) / replications.to_double()).sqrt()
  metric_estimate(
    estimate~,
    lower=(estimate - error).max(0.0),
    upper=(estimate + error).min(1.0),
    confidence_level=0.95,
  )
}

///|
pub fn monte_carlo_series(
  seed : Int,
  models : Array[ReliabilityModel],
  time : Double,
  replications : Int,
) -> MetricEstimate {
  if models.is_empty() {
    abort("series simulation requires components")
  }
  let state = RandomState::new(seed)
  let mut successes = 0.0
  for _ in 0..<replications {
    let mut works = true
    for model in models {
      let life = model_quantile(model, state.uniform().max(1.0e-9))
      if life <= time {
        works = false
      }
    }
    if works {
      successes += 1.0
    }
  }
  let estimate = successes / replications.to_double()
  let error = 1.96 *
    (estimate * (1.0 - estimate) / replications.to_double()).sqrt()
  metric_estimate(
    estimate~,
    lower=(estimate - error).max(0.0),
    upper=(estimate + error).min(1.0),
    confidence_level=0.95,
  )
}
