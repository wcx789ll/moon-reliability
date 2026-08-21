///|
/// A factor level in a reliability experiment.
pub struct ReliabilityFactor {
  factor_id : String
  level : Double
  lower : Double
  upper : Double
}

///|
pub fn reliability_factor(
  factor_id : String,
  level : Double,
  lower : Double,
  upper : Double,
) -> ReliabilityFactor {
  if upper < lower || level < lower || level > upper {
    abort("factor level outside declared bounds")
  }
  { factor_id, level, lower, upper }
}

///|
pub fn reliability_factor_normalized(factor : ReliabilityFactor) -> Double {
  if factor.upper == factor.lower {
    0.0
  } else {
    (factor.level - factor.lower) / (factor.upper - factor.lower)
  }
}

///|
pub fn reliability_factor_is_low(factor : ReliabilityFactor) -> Bool {
  factor.level == factor.lower
}

///|
pub fn reliability_factor_is_high(factor : ReliabilityFactor) -> Bool {
  factor.level == factor.upper
}

///|
/// One executed experimental trial with a response and exposure.
pub struct ReliabilityTrial {
  trial_id : Int
  factors : Array[ReliabilityFactor]
  response : Double
  exposure : Double
  failures : Int
  censored : Bool
  replicate : Int
}

///|
pub fn reliability_trial(
  trial_id : Int,
  factors : Array[ReliabilityFactor],
  response : Double,
  exposure : Double,
  failures : Int,
  censored : Bool,
  replicate : Int,
) -> ReliabilityTrial {
  if trial_id < 0 || exposure < 0.0 || failures < 0 || replicate < 0 {
    abort("invalid reliability trial")
  }
  { trial_id, factors, response, exposure, failures, censored, replicate }
}

///|
pub fn reliability_trial_id(trial : ReliabilityTrial) -> Int {
  trial.trial_id
}

///|
pub fn reliability_trial_failure_rate(trial : ReliabilityTrial) -> Double {
  if trial.exposure <= 0.0 {
    0.0
  } else {
    trial.failures.to_double() / trial.exposure
  }
}

///|
pub fn reliability_trial_failure_free(trial : ReliabilityTrial) -> Bool {
  trial.failures == 0 && !trial.censored
}

///|
pub fn reliability_trial_factor_level(
  trial : ReliabilityTrial,
  factor_id : String,
) -> Double {
  for factor in trial.factors {
    if factor.factor_id == factor_id {
      return factor.level
    }
  }
  0.0
}

///|
pub fn reliability_trial_factor_count(trial : ReliabilityTrial) -> Int {
  trial.factors.length()
}

///|
/// A treatment cell aggregates replicates at one factor combination.
pub struct ReliabilityTreatmentCell {
  cell_id : Int
  levels : Array[ReliabilityFactor]
  trials : Array[ReliabilityTrial]
}

///|
pub fn reliability_treatment_cell(
  cell_id : Int,
  levels : Array[ReliabilityFactor],
  trials : Array[ReliabilityTrial],
) -> ReliabilityTreatmentCell {
  if cell_id < 0 {
    abort("cell id must be non-negative")
  }
  { cell_id, levels, trials }
}

///|
pub fn reliability_cell_trial_count(cell : ReliabilityTreatmentCell) -> Int {
  cell.trials.length()
}

///|
pub fn reliability_cell_response_mean(
  cell : ReliabilityTreatmentCell,
) -> Double {
  if cell.trials.is_empty() {
    0.0
  } else {
    mean(cell.trials.map(trial => trial.response))
  }
}

///|
pub fn reliability_cell_response_variance(
  cell : ReliabilityTreatmentCell,
) -> Double {
  if cell.trials.length() < 2 {
    0.0
  } else {
    variance(cell.trials.map(trial => trial.response))
  }
}

///|
pub fn reliability_cell_total_exposure(
  cell : ReliabilityTreatmentCell,
) -> Double {
  cell.trials.fold(init=0.0, (sum, trial) => sum + trial.exposure)
}

///|
pub fn reliability_cell_total_failures(cell : ReliabilityTreatmentCell) -> Int {
  cell.trials.fold(init=0, (sum, trial) => sum + trial.failures)
}

///|
pub fn reliability_cell_failure_rate(cell : ReliabilityTreatmentCell) -> Double {
  let exposure = reliability_cell_total_exposure(cell)
  if exposure <= 0.0 {
    0.0
  } else {
    reliability_cell_total_failures(cell).to_double() / exposure
  }
}

///|
pub fn reliability_cell_is_balanced(cell : ReliabilityTreatmentCell) -> Bool {
  if cell.trials.is_empty() {
    true
  } else {
    let replicate = cell.trials[0].replicate
    cell.trials.fold(init=true, (balanced, trial) => {
      balanced && trial.replicate == replicate
    })
  }
}

///|
/// Main-effect estimate for a factor, with uncertainty and sample counts.
pub struct ReliabilityFactorEffect {
  factor_id : String
  low_mean : Double
  high_mean : Double
  effect : Double
  standard_error : Double
  observations : Int
}

///|
pub fn reliability_factor_effect(
  factor_id : String,
  low_mean : Double,
  high_mean : Double,
  standard_error : Double,
  observations : Int,
) -> ReliabilityFactorEffect {
  if standard_error < 0.0 || observations < 0 {
    abort("invalid factor effect")
  }
  {
    factor_id,
    low_mean,
    high_mean,
    effect: high_mean - low_mean,
    standard_error,
    observations,
  }
}

///|
pub fn reliability_factor_effect_signal(
  effect : ReliabilityFactorEffect,
) -> Double {
  if effect.standard_error == 0.0 {
    effect.effect.abs()
  } else {
    effect.effect.abs() / effect.standard_error
  }
}

///|
pub fn reliability_factor_effect_is_material(
  effect : ReliabilityFactorEffect,
  threshold : Double,
) -> Bool {
  reliability_factor_effect_signal(effect) >= threshold
}

///|
pub fn reliability_main_effect(
  trials : Array[ReliabilityTrial],
  factor_id : String,
) -> ReliabilityFactorEffect {
  let low = trials.filter_map(trial => {
    let factor = trial.factors.filter_map(f => {
      if f.factor_id == factor_id {
        Some(f)
      } else {
        None
      }
    })
    if factor.is_empty() || !reliability_factor_is_low(factor[0]) {
      None
    } else {
      Some(trial.response)
    }
  })
  let high = trials.filter_map(trial => {
    let factor = trial.factors.filter_map(f => {
      if f.factor_id == factor_id {
        Some(f)
      } else {
        None
      }
    })
    if factor.is_empty() || !reliability_factor_is_high(factor[0]) {
      None
    } else {
      Some(trial.response)
    }
  })
  let low_mean = if low.is_empty() { 0.0 } else { mean(low) }
  let high_mean = if high.is_empty() { 0.0 } else { mean(high) }
  let pooled = if low.length() + high.length() < 2 {
    0.0
  } else {
    let low_var = if low.length() < 2 { 0.0 } else { variance(low) }
    let high_var = if high.length() < 2 { 0.0 } else { variance(high) }
    (low_var + high_var).sqrt()
  }
  reliability_factor_effect(
    factor_id,
    low_mean,
    high_mean,
    pooled,
    low.length() + high.length(),
  )
}

///|
/// One-way analysis-of-variance decomposition for treatment cells.
pub struct ReliabilityAnova {
  grand_mean : Double
  between_sum_squares : Double
  within_sum_squares : Double
  between_degrees : Int
  within_degrees : Int
  f_statistic : Double
  explained_fraction : Double
}

///|
pub fn reliability_anova(
  cells : Array[ReliabilityTreatmentCell],
) -> ReliabilityAnova {
  let all = Array::new()
  for cell in cells {
    for trial in cell.trials {
      all.push(trial.response)
    }
  }
  if all.is_empty() {
    return {
      grand_mean: 0.0,
      between_sum_squares: 0.0,
      within_sum_squares: 0.0,
      between_degrees: 0,
      within_degrees: 0,
      f_statistic: 0.0,
      explained_fraction: 0.0,
    }
  }
  let grand = mean(all)
  let mut between = 0.0
  let mut within = 0.0
  for cell in cells {
    let count = cell.trials.length().to_double()
    let center = reliability_cell_response_mean(cell)
    between += count * (center - grand) * (center - grand)
    for trial in cell.trials {
      within += (trial.response - center) * (trial.response - center)
    }
  }
  let between_df = (cells.length() - 1).max(0)
  let within_df = (all.length() - cells.length()).max(0)
  let between_mean = if between_df == 0 {
    0.0
  } else {
    between / between_df.to_double()
  }
  let within_mean = if within_df == 0 {
    0.0
  } else {
    within / within_df.to_double()
  }
  let f = if within_mean == 0.0 { 0.0 } else { between_mean / within_mean }
  let total = between + within
  {
    grand_mean: grand,
    between_sum_squares: between,
    within_sum_squares: within,
    between_degrees: between_df,
    within_degrees: within_df,
    f_statistic: f,
    explained_fraction: if total == 0.0 {
      0.0
    } else {
      between / total
    },
  }
}

///|
pub fn reliability_anova_is_informative(
  summary : ReliabilityAnova,
  minimum_f : Double,
) -> Bool {
  summary.f_statistic >= minimum_f &&
  summary.between_degrees > 0 &&
  summary.within_degrees > 0
}

///|
pub fn reliability_anova_residual_standard_error(
  summary : ReliabilityAnova,
) -> Double {
  if summary.within_degrees == 0 {
    0.0
  } else {
    (summary.within_sum_squares / summary.within_degrees.to_double()).sqrt()
  }
}

///|
/// A linear response surface model with normalized coefficients.
pub struct ReliabilityResponseSurface {
  intercept : Double
  coefficients : Array[Double]
  residual_variance : Double
  condition_index : Double
}

///|
pub fn reliability_response_surface(
  intercept : Double,
  coefficients : Array[Double],
  residual_variance : Double,
  condition_index : Double,
) -> ReliabilityResponseSurface {
  if residual_variance < 0.0 || condition_index < 1.0 {
    abort("invalid response surface")
  }
  { intercept, coefficients, residual_variance, condition_index }
}

///|
pub fn reliability_response_surface_predict(
  surface : ReliabilityResponseSurface,
  inputs : Array[Double],
) -> Double {
  let count = surface.coefficients.length().min(inputs.length())
  let mut result = surface.intercept
  for i in 0..<count {
    result += surface.coefficients[i] * inputs[i]
  }
  result
}

///|
pub fn reliability_response_surface_sensitivity(
  surface : ReliabilityResponseSurface,
) -> Double {
  surface.coefficients
  .fold(init=0.0, (sum, coefficient) => sum + coefficient * coefficient)
  .sqrt()
}

///|
pub fn reliability_response_surface_is_stable(
  surface : ReliabilityResponseSurface,
  maximum_condition : Double,
) -> Bool {
  surface.condition_index <= maximum_condition
}

///|
pub fn reliability_response_surface_bounds(
  surface : ReliabilityResponseSurface,
  inputs : Array[Double],
  z : Double,
) -> (Double, Double) {
  let prediction = reliability_response_surface_predict(surface, inputs)
  let margin = z.abs() * surface.residual_variance.sqrt()
  (prediction - margin, prediction + margin)
}

///|
pub fn reliability_response_surface_grid(
  surface : ReliabilityResponseSurface,
  lower : Double,
  upper : Double,
  steps : Int,
) -> Array[Double] {
  if steps < 1 || upper < lower {
    abort("invalid response surface grid")
  }
  let result = Array::new()
  for i in 0..<=steps {
    let fraction = i.to_double() / steps.to_double()
    let input = lower + fraction * (upper - lower)
    result.push(
      reliability_response_surface_predict(surface, Array::make(1, input)),
    )
  }
  result
}

///|
/// Sample-size and power planning result for a reliability comparison.
pub struct ReliabilityPowerPlan {
  effect : Double
  standard_deviation : Double
  alpha : Double
  target_power : Double
  required_per_group : Int
  achieved_power : Double
}

///|
pub fn reliability_power_plan(
  effect : Double,
  standard_deviation : Double,
  alpha : Double,
  target_power : Double,
) -> ReliabilityPowerPlan {
  if standard_deviation <= 0.0 ||
    alpha <= 0.0 ||
    alpha >= 1.0 ||
    target_power <= 0.0 ||
    target_power >= 1.0 {
    abort("invalid power plan")
  }
  let standardized = effect.abs() / standard_deviation
  let z_alpha = (-2.0 * @math.ln(alpha / 2.0)).sqrt()
  let z_power = (-2.0 * @math.ln(1.0 - target_power)).sqrt()
  let required = if standardized == 0.0 {
    1000000000
  } else {
    (2.0 * @math.pow(z_alpha + z_power, 2.0) / @math.pow(standardized, 2.0))
    .ceil()
    .to_int()
    .max(2)
  }
  let achieved = if required <= 0 || standardized == 0.0 {
    0.0
  } else {
    1.0 - @math.exp(-standardized * (required.to_double() / 2.0).sqrt())
  }
  {
    effect,
    standard_deviation,
    alpha,
    target_power,
    required_per_group: required,
    achieved_power: achieved.min(1.0).max(0.0),
  }
}

///|
pub fn reliability_power_plan_total_sample(plan : ReliabilityPowerPlan) -> Int {
  plan.required_per_group * 2
}

///|
pub fn reliability_power_plan_is_sufficient(
  plan : ReliabilityPowerPlan,
) -> Bool {
  plan.achieved_power >= plan.target_power
}

///|
/// Sequential monitoring boundary for an experiment that may stop early.
pub struct ReliabilitySequentialBoundary {
  look : Int
  information_fraction : Double
  upper : Double
  lower : Double
  should_continue : Bool
}

///|
pub fn reliability_sequential_boundary(
  look : Int,
  information_fraction : Double,
  alpha : Double,
  beta : Double,
) -> ReliabilitySequentialBoundary {
  if look < 1 ||
    information_fraction <= 0.0 ||
    information_fraction > 1.0 ||
    alpha <= 0.0 ||
    alpha >= 1.0 ||
    beta <= 0.0 ||
    beta >= 1.0 {
    abort("invalid sequential boundary")
  }
  let information = information_fraction.sqrt()
  let upper = (-2.0 * @math.ln(alpha)).sqrt() / information
  let lower = -(-2.0 * @math.ln(beta)).sqrt() / information
  { look, information_fraction, upper, lower, should_continue: true }
}

///|
pub fn reliability_sequential_decision(
  boundary : ReliabilitySequentialBoundary,
  statistic : Double,
) -> String {
  if statistic >= boundary.upper {
    "accept_alternative"
  } else if statistic <= boundary.lower {
    "accept_null"
  } else {
    "continue"
  }
}

///|
pub fn reliability_sequential_can_stop(
  boundary : ReliabilitySequentialBoundary,
  statistic : Double,
) -> Bool {
  reliability_sequential_decision(boundary, statistic) != "continue"
}

///|
pub fn reliability_sequential_operating_characteristic(
  boundary : ReliabilitySequentialBoundary,
  statistics : Array[Double],
) -> (Int, Int, Int) {
  let mut null_count = 0
  let mut alternative_count = 0
  let mut continue_count = 0
  for statistic in statistics {
    match reliability_sequential_decision(boundary, statistic) {
      "accept_null" => null_count += 1
      "accept_alternative" => alternative_count += 1
      _ => continue_count += 1
    }
  }
  (null_count, alternative_count, continue_count)
}

///|
pub fn reliability_trial_residuals(
  trials : Array[ReliabilityTrial],
  expected : Array[Double],
) -> Array[Double] {
  if trials.length() != expected.length() {
    abort("residual arrays must have equal length")
  }
  Array::makei(trials.length(), i => trials[i].response - expected[i])
}

///|
pub fn reliability_residual_root_mean_square(
  residuals : Array[Double],
) -> Double {
  if residuals.is_empty() {
    0.0
  } else {
    (residuals.fold(init=0.0, (sum, value) => sum + value * value) /
    residuals.length().to_double()).sqrt()
  }
}

///|
pub fn reliability_residual_bias(residuals : Array[Double]) -> Double {
  if residuals.is_empty() {
    0.0
  } else {
    mean(residuals)
  }
}

///|
pub fn reliability_residual_within_limits(
  residuals : Array[Double],
  limit : Double,
) -> Bool {
  if limit < 0.0 {
    false
  } else {
    residuals.fold(init=true, (ok, value) => ok && value.abs() <= limit)
  }
}

///|
pub fn reliability_experiment_checksum(
  trials : Array[ReliabilityTrial],
  anova : ReliabilityAnova,
) -> Double {
  anova.grand_mean +
  anova.f_statistic +
  anova.explained_fraction +
  trials.fold(init=0.0, (sum, trial) => sum + trial.response + trial.exposure)
}
