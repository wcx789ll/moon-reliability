///|
/// Piecewise bathtub-hazard model for early, random and wear-out failures.
pub struct BathtubHazard {
  early_rate : Double
  random_rate : Double
  wearout_scale : Double
  wearout_shape : Double
}

///|
pub fn bathtub_hazard(
  early_rate~ : Double,
  random_rate~ : Double,
  wearout_scale~ : Double,
  wearout_shape~ : Double,
) -> BathtubHazard {
  if early_rate < 0.0 ||
    random_rate < 0.0 ||
    wearout_scale <= 0.0 ||
    wearout_shape <= 0.0 {
    abort("invalid bathtub hazard")
  }
  { early_rate, random_rate, wearout_scale, wearout_shape }
}

///|
pub fn BathtubHazard::early_component(
  self : BathtubHazard,
  time : Double,
) -> Double {
  self.early_rate * @math.exp(-self.early_rate * time)
}

///|
pub fn BathtubHazard::wearout_component(
  self : BathtubHazard,
  time : Double,
) -> Double {
  self.wearout_shape /
  self.wearout_scale *
  @math.pow(time / self.wearout_scale, self.wearout_shape - 1.0)
}

///|
pub fn BathtubHazard::hazard(self : BathtubHazard, time : Double) -> Double {
  self.random_rate + self.early_component(time) + self.wearout_component(time)
}

///|
pub fn BathtubHazard::cumulative_hazard(
  self : BathtubHazard,
  time : Double,
) -> Double {
  self.random_rate * time +
  (1.0 - @math.exp(-self.early_rate * time)) +
  @math.pow(time / self.wearout_scale, self.wearout_shape)
}

///|
pub fn BathtubHazard::survival(self : BathtubHazard, time : Double) -> Double {
  @math.exp(-self.cumulative_hazard(time))
}

///|
pub fn BathtubHazard::cdf(self : BathtubHazard, time : Double) -> Double {
  1.0 - self.survival(time)
}

///|
pub fn BathtubHazard::pdf(self : BathtubHazard, time : Double) -> Double {
  self.hazard(time) * self.survival(time)
}

///|
pub fn BathtubHazard::quantile(self : BathtubHazard, p : Double) -> Double {
  if p <= 0.0 || p >= 1.0 {
    abort("p must be in (0, 1)")
  }
  let mut lower = 0.0
  let mut upper = self.wearout_scale
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
pub fn BathtubHazard::mean(self : BathtubHazard) -> Double {
  let upper = self.quantile(0.999999)
  let grid = linspace(0.0, upper, 400)
  let mut total = 0.0
  for i in 0..<(grid.length() - 1) {
    total += (self.survival(grid[i]) + self.survival(grid[i + 1])) *
      (grid[i + 1] - grid[i]) /
      2.0
  }
  total
}

///|
pub fn BathtubHazard::phase(self : BathtubHazard, time : Double) -> String {
  let derivative = self.wearout_shape *
    (self.wearout_shape - 1.0) /
    self.wearout_scale *
    @math.pow(time / self.wearout_scale, self.wearout_shape - 2.0) -
    self.early_rate * self.early_rate * @math.exp(-self.early_rate * time)
  if derivative < -1.0e-8 {
    "early-life"
  } else if derivative > 1.0e-8 {
    "wear-out"
  } else {
    "random-failure"
  }
}

///|
pub fn fit_bathtub_hazard(records : Array[LifeObservation]) -> BathtubHazard {
  if records.is_empty() {
    abort("bathtub fit requires records")
  }
  let summary = summarize(records)
  let early = 0.2 / summary.mean.max(1.0)
  let random = observed_event_count(records).to_double() /
    total_exposure(records).max(1.0)
  let scale = summary.median.max(1.0)
  bathtub_hazard(
    early_rate=early,
    random_rate=random,
    wearout_scale=scale,
    wearout_shape=2.0,
  )
}

///|
pub struct FailureModeContribution {
  name : String
  probability : Double
  cost : Double
  risk_contribution : Double
}

///|
pub fn failure_mode_contribution(
  name~ : String,
  probability~ : Double,
  cost~ : Double,
) -> FailureModeContribution {
  { name, probability, cost, risk_contribution: probability * cost }
}

///|
pub fn rank_failure_modes(
  modes : Array[FailureModeContribution],
) -> Array[FailureModeContribution] {
  let result = modes.copy()
  result.sort_by((left, right) => {
    if left.risk_contribution > right.risk_contribution {
      -1
    } else if left.risk_contribution < right.risk_contribution {
      1
    } else {
      0
    }
  })
  result
}

///|
pub fn total_failure_mode_risk(
  modes : Array[FailureModeContribution],
) -> Double {
  modes.fold(init=0.0, (sum, mode) => sum + mode.risk_contribution)
}

///|
pub fn mode_risk_share(
  mode : FailureModeContribution,
  modes : Array[FailureModeContribution],
) -> Double {
  mode.risk_contribution / total_failure_mode_risk(modes).max(1.0e-300)
}

///|
pub fn reduce_mode_probability(
  mode : FailureModeContribution,
  reduction : Double,
) -> FailureModeContribution {
  let probability = mode.probability * (1.0 - reduction.max(0.0).min(1.0))
  failure_mode_contribution(name=mode.name, probability~, cost=mode.cost)
}

///|
pub fn expected_risk_after_mitigation(
  modes : Array[FailureModeContribution],
  reductions : Array[Double],
) -> Double {
  if modes.length() != reductions.length() {
    abort("mode mitigation arrays mismatch")
  }
  let mut total = 0.0
  for i in 0..<modes.length() {
    total += reduce_mode_probability(modes[i], reductions[i]).risk_contribution
  }
  total
}
