///|
/// A reliability demonstration test plan.
pub struct DemonstrationTestPlan {
  target_reliability : Double
  confidence : Double
  units : Int
  duration : Double
  allowed_failures : Int
  expected_failures : Double
  total_test_hours : Double
  test_cost : Double
  pass_probability : Double
  name : String
}

///|
pub fn demonstration_test_plan(
  target_reliability : Double,
  confidence : Double,
  units : Int,
  duration : Double,
  allowed_failures : Int,
  test_cost : Double,
  name : String,
) -> DemonstrationTestPlan {
  if target_reliability <= 0.0 ||
    target_reliability >= 1.0 ||
    confidence <= 0.0 ||
    confidence >= 1.0 ||
    units < 1 ||
    duration <= 0.0 ||
    allowed_failures < 0 ||
    allowed_failures >= units ||
    test_cost < 0.0 {
    abort("invalid demonstration test plan")
  }
  let expected = units.to_double() * (1.0 - target_reliability)
  let hours = units.to_double() * duration
  let pass_probability = demonstration_pass_probability(
    target_reliability, units, allowed_failures,
  )
  {
    target_reliability,
    confidence,
    units,
    duration,
    allowed_failures,
    expected_failures: expected,
    total_test_hours: hours,
    test_cost: hours * test_cost,
    pass_probability,
    name,
  }
}

///|
pub fn demonstration_pass_probability(
  reliability : Double,
  units : Int,
  allowed_failures : Int,
) -> Double {
  if reliability < 0.0 ||
    reliability > 1.0 ||
    units < 0 ||
    allowed_failures < 0 ||
    allowed_failures > units {
    abort("invalid binomial probability inputs")
  }
  let failure_probability = 1.0 - reliability
  let mut total = 0.0
  for failures in 0..<=allowed_failures {
    total += @math.exp(
      log_binomial_probability(
        units, failures, failure_probability, reliability,
      ),
    )
  }
  total.min(1.0).max(0.0)
}

///|
fn log_binomial_probability(
  n : Int,
  k : Int,
  probability : Double,
  complement : Double,
) -> Double {
  if k == 0 {
    n.to_double() * safe_log_probability(complement)
  } else if k == n {
    n.to_double() * safe_log_probability(probability)
  } else {
    log_factorial(n) -
    log_factorial(k) -
    log_factorial(n - k) +
    k.to_double() * safe_log_probability(probability) +
    (n - k).to_double() * safe_log_probability(complement)
  }
}

///|
pub fn demonstration_sample_size(
  target_reliability : Double,
  confidence : Double,
  allowed_failures : Int,
) -> Int {
  if target_reliability <= 0.0 ||
    target_reliability >= 1.0 ||
    confidence <= 0.0 ||
    confidence >= 1.0 ||
    allowed_failures < 0 {
    abort("invalid sample size inputs")
  }
  let mut units = allowed_failures + 1
  while units < 100000 {
    if demonstration_pass_probability(
        target_reliability, units, allowed_failures,
      ) <=
      1.0 - confidence {
      return units
    }
    units += 1
  }
  100000
}

///|
pub fn zero_failure_sample_size(
  target_reliability : Double,
  confidence : Double,
) -> Int {
  demonstration_sample_size(target_reliability, confidence, 0)
}

///|
pub fn zero_failure_test_time(
  target_reliability : Double,
  confidence : Double,
  failure_rate : Double,
) -> Double {
  if failure_rate <= 0.0 {
    abort("failure rate must be positive")
  }
  let units = zero_failure_sample_size(target_reliability, confidence)
  -@math.ln(1.0 - confidence) / failure_rate / units.to_double()
}

///|
pub fn demonstration_duration_for_units(
  target_reliability : Double,
  confidence : Double,
  units : Int,
  failure_rate : Double,
) -> Double {
  if target_reliability <= 0.0 ||
    target_reliability >= 1.0 ||
    confidence <= 0.0 ||
    confidence >= 1.0 ||
    units < 1 ||
    failure_rate <= 0.0 {
    abort("invalid duration inputs")
  }
  let probability = (1.0 - confidence).max(1.0e-300)
  -@math.ln(probability) / failure_rate / units.to_double()
}

///|
pub fn demonstration_plan_cost(
  plan : DemonstrationTestPlan,
  cost_per_hour : Double,
) -> Double {
  if cost_per_hour < 0.0 {
    abort("cost per hour must be non-negative")
  }
  plan.total_test_hours * cost_per_hour
}

///|
pub fn demonstration_plan_margin(
  plan : DemonstrationTestPlan,
  observed_failures : Int,
) -> Int {
  plan.allowed_failures - observed_failures
}

///|
pub fn demonstration_plan_passes(
  plan : DemonstrationTestPlan,
  observed_failures : Int,
) -> Bool {
  observed_failures >= 0 && observed_failures <= plan.allowed_failures
}

///|
pub fn demonstration_plan_evidence_fraction(
  plan : DemonstrationTestPlan,
  observed_hours : Double,
) -> Double {
  if observed_hours < 0.0 {
    abort("observed hours must be non-negative")
  }
  (observed_hours / plan.total_test_hours).min(1.0)
}

///|
pub fn demonstration_plan_progress(
  plan : DemonstrationTestPlan,
  observed_hours : Double,
  observed_failures : Int,
) -> Double {
  let evidence = demonstration_plan_evidence_fraction(plan, observed_hours)
  let failure_margin = if plan.allowed_failures == 0 {
    if observed_failures == 0 {
      1.0
    } else {
      0.0
    }
  } else {
    (plan.allowed_failures - observed_failures).to_double() /
    plan.allowed_failures.to_double()
  }
  (0.7 * evidence + 0.3 * failure_margin.max(0.0).min(1.0)).min(1.0)
}

///|
pub fn demonstration_plan_status(
  plan : DemonstrationTestPlan,
  observed_hours : Double,
  observed_failures : Int,
) -> String {
  if observed_failures > plan.allowed_failures {
    "failed"
  } else if observed_hours >= plan.total_test_hours {
    "complete"
  } else {
    "running"
  }
}

///|
pub fn demonstration_plan_checksum(plan : DemonstrationTestPlan) -> Double {
  plan.target_reliability +
  plan.confidence +
  plan.units.to_double() +
  plan.duration +
  plan.allowed_failures.to_double() +
  plan.expected_failures +
  plan.total_test_hours +
  plan.test_cost +
  plan.pass_probability
}

///|
pub struct PoissonTestPlan {
  target_rate : Double
  confidence : Double
  exposure : Double
  allowed_events : Int
  event_probability : Double
  cost : Double
  name : String
}

///|
pub fn poisson_test_plan(
  target_rate : Double,
  confidence : Double,
  exposure : Double,
  allowed_events : Int,
  cost_per_unit : Double,
  name : String,
) -> PoissonTestPlan {
  if target_rate <= 0.0 ||
    confidence <= 0.0 ||
    confidence >= 1.0 ||
    exposure <= 0.0 ||
    allowed_events < 0 ||
    cost_per_unit < 0.0 {
    abort("invalid Poisson test plan")
  }
  let mean_events = target_rate * exposure
  {
    target_rate,
    confidence,
    exposure,
    allowed_events,
    event_probability: poisson_cdf(allowed_events, mean_events),
    cost: exposure * cost_per_unit,
    name,
  }
}

///|
pub fn poisson_probability(events : Int, mean_events : Double) -> Double {
  if events < 0 || mean_events < 0.0 {
    abort("invalid Poisson probability inputs")
  }
  @math.exp(
    events.to_double() * safe_log_probability(mean_events) -
    mean_events -
    log_factorial(events),
  )
}

///|
pub fn poisson_cdf(events : Int, mean_events : Double) -> Double {
  if events < 0 || mean_events < 0.0 {
    abort("invalid Poisson CDF inputs")
  }
  let mut total = 0.0
  for k in 0..<=events {
    total += poisson_probability(k, mean_events)
  }
  total.min(1.0)
}

///|
pub fn poisson_survival(events : Int, mean_events : Double) -> Double {
  (1.0 - poisson_cdf(events, mean_events)).max(0.0)
}

///|
pub fn poisson_expected_events(plan : PoissonTestPlan) -> Double {
  plan.target_rate * plan.exposure
}

///|
pub fn poisson_plan_passes(
  plan : PoissonTestPlan,
  observed_events : Int,
) -> Bool {
  observed_events >= 0 && observed_events <= plan.allowed_events
}

///|
pub fn poisson_plan_margin(
  plan : PoissonTestPlan,
  observed_events : Int,
) -> Int {
  plan.allowed_events - observed_events
}

///|
pub fn poisson_upper_rate_bound(
  events : Int,
  exposure : Double,
  confidence : Double,
) -> Double {
  if events < 0 || exposure <= 0.0 || confidence <= 0.0 || confidence >= 1.0 {
    abort("invalid Poisson rate bound inputs")
  }
  let mut low = 0.0
  let mut high = (events + 10).to_double() / exposure * 10.0
  for _ in 0..<80 {
    let middle = (low + high) / 2.0
    let probability = poisson_cdf(events, middle * exposure)
    if probability > 1.0 - confidence {
      low = middle
    } else {
      high = middle
    }
  }
  high
}

///|
pub fn poisson_lower_rate_bound(
  events : Int,
  exposure : Double,
  confidence : Double,
) -> Double {
  if events <= 0 || exposure <= 0.0 || confidence <= 0.0 || confidence >= 1.0 {
    return 0.0
  }
  let mut low = 0.0
  let mut high = events.to_double() / exposure
  for _ in 0..<80 {
    let middle = (low + high) / 2.0
    let probability = poisson_survival(events - 1, middle * exposure)
    if probability > 1.0 - confidence {
      high = middle
    } else {
      low = middle
    }
  }
  low
}

///|
pub struct TestCell {
  cell_id : Int
  stress : Double
  units : Int
  duration : Double
  cost_per_unit_hour : Double
  expected_rate : Double
  failures : Int
}

///|
pub fn test_cell(
  cell_id : Int,
  stress : Double,
  units : Int,
  duration : Double,
  cost_per_unit_hour : Double,
  expected_rate : Double,
  failures : Int,
) -> TestCell {
  if cell_id < 0 ||
    stress < 0.0 ||
    units < 1 ||
    duration <= 0.0 ||
    cost_per_unit_hour < 0.0 ||
    expected_rate < 0.0 ||
    failures < 0 {
    abort("invalid test cell")
  }
  {
    cell_id,
    stress,
    units,
    duration,
    cost_per_unit_hour,
    expected_rate,
    failures,
  }
}

///|
pub fn test_cell_exposure(cell : TestCell) -> Double {
  cell.units.to_double() * cell.duration
}

///|
pub fn test_cell_expected_failures(cell : TestCell) -> Double {
  test_cell_exposure(cell) * cell.expected_rate
}

///|
pub fn test_cell_cost(cell : TestCell) -> Double {
  test_cell_exposure(cell) * cell.cost_per_unit_hour
}

///|
pub fn test_cell_failure_rate(cell : TestCell) -> Double {
  if test_cell_exposure(cell) == 0.0 {
    0.0
  } else {
    cell.failures.to_double() / test_cell_exposure(cell)
  }
}

///|
pub fn test_cell_failure_residual(cell : TestCell) -> Double {
  cell.failures.to_double() - test_cell_expected_failures(cell)
}

///|
pub fn test_cell_passes(cell : TestCell, maximum_failures : Int) -> Bool {
  cell.failures >= 0 && cell.failures <= maximum_failures
}

///|
pub fn test_cell_stress_factor(
  cell : TestCell,
  baseline_stress : Double,
) -> Double {
  if baseline_stress <= 0.0 {
    abort("baseline stress must be positive")
  }
  cell.stress / baseline_stress
}

///|
pub fn test_cell_acceleration(
  cell : TestCell,
  baseline_stress : Double,
  exponent : Double,
) -> Double {
  if exponent < 0.0 {
    abort("acceleration exponent must be non-negative")
  }
  @math.pow(test_cell_stress_factor(cell, baseline_stress), exponent)
}

///|
pub struct TestMatrix {
  cells : Array[TestCell]
  name : String
  confidence : Double
  target_rate : Double
}

///|
pub fn test_matrix(
  cells : Array[TestCell],
  name : String,
  confidence : Double,
  target_rate : Double,
) -> TestMatrix {
  if cells.is_empty() ||
    confidence <= 0.0 ||
    confidence >= 1.0 ||
    target_rate < 0.0 {
    abort("invalid test matrix")
  }
  { cells, name, confidence, target_rate }
}

///|
pub fn test_matrix_cell_count(matrix : TestMatrix) -> Int {
  matrix.cells.length()
}

///|
pub fn test_matrix_total_units(matrix : TestMatrix) -> Int {
  matrix.cells.fold(init=0, (total, cell) => total + cell.units)
}

///|
pub fn test_matrix_total_exposure(matrix : TestMatrix) -> Double {
  matrix.cells.fold(init=0.0, (total, cell) => total + test_cell_exposure(cell))
}

///|
pub fn test_matrix_total_cost(matrix : TestMatrix) -> Double {
  matrix.cells.fold(init=0.0, (total, cell) => total + test_cell_cost(cell))
}

///|
pub fn test_matrix_total_failures(matrix : TestMatrix) -> Int {
  matrix.cells.fold(init=0, (total, cell) => total + cell.failures)
}

///|
pub fn test_matrix_expected_failures(matrix : TestMatrix) -> Double {
  matrix.cells.fold(init=0.0, (total, cell) => {
    total + test_cell_expected_failures(cell)
  })
}

///|
pub fn test_matrix_failure_rate(matrix : TestMatrix) -> Double {
  let exposure = test_matrix_total_exposure(matrix)
  if exposure == 0.0 {
    0.0
  } else {
    test_matrix_total_failures(matrix).to_double() / exposure
  }
}

///|
pub fn test_matrix_rate_interval(matrix : TestMatrix) -> MetricEstimate {
  let lower = poisson_lower_rate_bound(
    test_matrix_total_failures(matrix),
    test_matrix_total_exposure(matrix),
    matrix.confidence,
  )
  let upper = poisson_upper_rate_bound(
    test_matrix_total_failures(matrix),
    test_matrix_total_exposure(matrix),
    matrix.confidence,
  )
  metric_estimate(
    estimate=test_matrix_failure_rate(matrix),
    lower~,
    upper~,
    confidence_level=matrix.confidence,
  )
}

///|
pub fn test_matrix_stress_values(matrix : TestMatrix) -> Array[Double] {
  matrix.cells.map(cell => cell.stress)
}

///|
pub fn test_matrix_exposure_by_cell(matrix : TestMatrix) -> Array[Double] {
  matrix.cells.map(cell => test_cell_exposure(cell))
}

///|
pub fn test_matrix_failure_rates(matrix : TestMatrix) -> Array[Double] {
  matrix.cells.map(cell => test_cell_failure_rate(cell))
}

///|
pub fn test_matrix_cost_share(matrix : TestMatrix) -> Array[Double] {
  let total = test_matrix_total_cost(matrix)
  if total == 0.0 {
    matrix.cells.map(_ => 0.0)
  } else {
    matrix.cells.map(cell => test_cell_cost(cell) / total)
  }
}

///|
pub fn test_matrix_failure_share(matrix : TestMatrix) -> Array[Double] {
  let total = test_matrix_total_failures(matrix)
  if total == 0 {
    matrix.cells.map(_ => 0.0)
  } else {
    matrix.cells.map(cell => cell.failures.to_double() / total.to_double())
  }
}

///|
pub fn test_matrix_best_cell(matrix : TestMatrix) -> TestCell {
  let mut best = matrix.cells[0]
  for cell in matrix.cells[1:] {
    if test_cell_cost(cell) < test_cell_cost(best) {
      best = cell
    }
  }
  best
}

///|
pub fn test_matrix_worst_cell(matrix : TestMatrix) -> TestCell {
  let mut worst = matrix.cells[0]
  for cell in matrix.cells[1:] {
    if test_cell_failure_rate(cell) > test_cell_failure_rate(worst) {
      worst = cell
    }
  }
  worst
}

///|
pub fn test_matrix_compliance(
  matrix : TestMatrix,
  maximum_rate : Double,
) -> Bool {
  test_matrix_failure_rate(matrix) <= maximum_rate
}

///|
pub fn test_matrix_progress(
  matrix : TestMatrix,
  planned_exposure : Double,
) -> Double {
  if planned_exposure <= 0.0 {
    abort("planned exposure must be positive")
  }
  (test_matrix_total_exposure(matrix) / planned_exposure).min(1.0)
}

///|
pub fn test_matrix_checksum(matrix : TestMatrix) -> Double {
  matrix.cells.fold(init=matrix.confidence + matrix.target_rate, (total, cell) => {
    total +
    cell.cell_id.to_double() +
    cell.stress +
    cell.units.to_double() +
    cell.duration +
    cell.failures.to_double()
  })
}

///|
pub struct SequentialTestBoundary {
  accept_failures : Int
  reject_failures : Int
  minimum_exposure : Double
  maximum_exposure : Double
  target_rate : Double
  adverse_rate : Double
}

///|
pub fn sequential_test_boundary(
  target_rate : Double,
  adverse_rate : Double,
  alpha : Double,
  beta : Double,
  minimum_exposure : Double,
  maximum_exposure : Double,
) -> SequentialTestBoundary {
  if target_rate <= 0.0 ||
    adverse_rate <= target_rate ||
    alpha <= 0.0 ||
    alpha >= 1.0 ||
    beta <= 0.0 ||
    beta >= 1.0 ||
    minimum_exposure <= 0.0 ||
    maximum_exposure <= minimum_exposure {
    abort("invalid sequential test boundary")
  }
  {
    accept_failures: @math.ln((beta / alpha).abs()).ceil().to_int().max(0),
    reject_failures: @math.ln((1.0 - beta) / alpha).ceil().to_int().max(1),
    minimum_exposure,
    maximum_exposure,
    target_rate,
    adverse_rate,
  }
}

///|
pub fn sequential_accepts(
  boundary : SequentialTestBoundary,
  failures : Int,
  exposure : Double,
) -> Bool {
  exposure >= boundary.minimum_exposure && failures <= boundary.accept_failures
}

///|
pub fn sequential_rejects(
  boundary : SequentialTestBoundary,
  failures : Int,
  exposure : Double,
) -> Bool {
  exposure >= boundary.minimum_exposure && failures >= boundary.reject_failures
}

///|
pub fn sequential_test_status(
  boundary : SequentialTestBoundary,
  failures : Int,
  exposure : Double,
) -> String {
  if sequential_rejects(boundary, failures, exposure) {
    "reject"
  } else if sequential_accepts(boundary, failures, exposure) {
    "accept"
  } else if exposure >= boundary.maximum_exposure {
    "inconclusive"
  } else {
    "continue"
  }
}

///|
pub fn sequential_failure_rate(
  boundary : SequentialTestBoundary,
  failures : Int,
  exposure : Double,
) -> Double {
  if boundary.target_rate < 0.0 || exposure <= 0.0 {
    abort("exposure must be positive")
  }
  failures.to_double() / exposure
}

///|
pub fn sequential_rate_margin(
  boundary : SequentialTestBoundary,
  failures : Int,
  exposure : Double,
) -> Double {
  boundary.target_rate - sequential_failure_rate(boundary, failures, exposure)
}

///|
pub fn sequential_operating_characteristic(
  boundary : SequentialTestBoundary,
  true_rate : Double,
  exposure : Double,
) -> Double {
  if true_rate < 0.0 || exposure < 0.0 {
    abort("invalid operating characteristic inputs")
  }
  let mean_events = true_rate * exposure
  poisson_cdf(boundary.accept_failures, mean_events)
}

///|
pub struct ReliabilityTestEvidence {
  planned_exposure : Double
  observed_exposure : Double
  planned_failures : Int
  observed_failures : Int
  target_rate : Double
  confidence : Double
  lower_rate : Double
  upper_rate : Double
  evidence_fraction : Double
  conclusion : String
}

///|
pub fn reliability_test_evidence(
  planned_exposure : Double,
  observed_exposure : Double,
  planned_failures : Int,
  observed_failures : Int,
  target_rate : Double,
  confidence : Double,
) -> ReliabilityTestEvidence {
  if planned_exposure <= 0.0 ||
    observed_exposure < 0.0 ||
    planned_failures < 0 ||
    observed_failures < 0 ||
    target_rate < 0.0 ||
    confidence <= 0.0 ||
    confidence >= 1.0 {
    abort("invalid test evidence")
  }
  let lower = poisson_lower_rate_bound(
    observed_failures,
    observed_exposure.max(1.0e-12),
    confidence,
  )
  let upper = poisson_upper_rate_bound(
    observed_failures,
    observed_exposure.max(1.0e-12),
    confidence,
  )
  let conclusion = if observed_failures > planned_failures {
    "failed"
  } else if observed_exposure >= planned_exposure && upper <= target_rate {
    "demonstrated"
  } else {
    "incomplete"
  }
  {
    planned_exposure,
    observed_exposure,
    planned_failures,
    observed_failures,
    target_rate,
    confidence,
    lower_rate: lower,
    upper_rate: upper,
    evidence_fraction: (observed_exposure / planned_exposure).min(1.0),
    conclusion,
  }
}

///|
pub fn evidence_is_pass(evidence : ReliabilityTestEvidence) -> Bool {
  evidence.conclusion == "demonstrated"
}

///|
pub fn evidence_is_complete(evidence : ReliabilityTestEvidence) -> Bool {
  evidence.conclusion != "incomplete"
}

///|
pub fn evidence_remaining_exposure(
  evidence : ReliabilityTestEvidence,
) -> Double {
  (evidence.planned_exposure - evidence.observed_exposure).max(0.0)
}

///|
pub fn evidence_remaining_failures(evidence : ReliabilityTestEvidence) -> Int {
  (evidence.planned_failures - evidence.observed_failures).max(0)
}

///|
pub fn evidence_margin(evidence : ReliabilityTestEvidence) -> Double {
  evidence.target_rate - evidence.upper_rate
}

///|
pub fn evidence_quality_score(evidence : ReliabilityTestEvidence) -> Double {
  let exposure_score = evidence.evidence_fraction
  let rate_score = (evidence.target_rate / evidence.upper_rate.max(1.0e-300)).min(
    1.0,
  )
  (0.5 * exposure_score + 0.5 * rate_score).min(1.0)
}

///|
pub fn evidence_checksum(evidence : ReliabilityTestEvidence) -> Double {
  evidence.planned_exposure +
  evidence.observed_exposure +
  evidence.planned_failures.to_double() +
  evidence.observed_failures.to_double() +
  evidence.target_rate +
  evidence.confidence +
  evidence.lower_rate +
  evidence.upper_rate
}

///|
pub fn confidence_from_zero_failures(
  target_reliability : Double,
  units : Int,
) -> Double {
  if target_reliability <= 0.0 || target_reliability >= 1.0 || units < 1 {
    abort("invalid zero-failure confidence inputs")
  }
  1.0 - @math.pow(target_reliability, units.to_double())
}

///|
pub fn reliability_lower_bound_zero_failures(
  units : Int,
  confidence : Double,
) -> Double {
  if units < 1 || confidence <= 0.0 || confidence >= 1.0 {
    abort("invalid lower bound inputs")
  }
  @math.pow(1.0 - confidence, 1.0 / units.to_double())
}

///|
pub fn reliability_lower_bound_failures(
  units : Int,
  failures : Int,
  confidence : Double,
) -> Double {
  if units < 1 ||
    failures < 0 ||
    failures > units ||
    confidence <= 0.0 ||
    confidence >= 1.0 {
    abort("invalid reliability bound inputs")
  }
  let observed = (units - failures).to_double() / units.to_double()
  (observed -
  standard_normal_inv(0.5 + confidence / 2.0) *
  (observed * (1.0 - observed) / units.to_double()).sqrt()).max(0.0)
}

///|
pub fn reliability_upper_bound_failures(
  units : Int,
  failures : Int,
  confidence : Double,
) -> Double {
  if units < 1 ||
    failures < 0 ||
    failures > units ||
    confidence <= 0.0 ||
    confidence >= 1.0 {
    abort("invalid reliability bound inputs")
  }
  let observed = (units - failures).to_double() / units.to_double()
  (observed +
  standard_normal_inv(0.5 + confidence / 2.0) *
  (observed * (1.0 - observed) / units.to_double()).sqrt()).min(1.0)
}

///|
pub fn test_planning_information_gain(
  old_confidence : Double,
  new_confidence : Double,
) -> Double {
  if old_confidence <= 0.0 ||
    old_confidence >= 1.0 ||
    new_confidence <= 0.0 ||
    new_confidence >= 1.0 {
    abort("confidence values must be in (0, 1)")
  }
  new_confidence - old_confidence
}

///|
pub fn test_planning_cost_effectiveness(
  information_gain : Double,
  cost : Double,
) -> Double {
  if cost < 0.0 {
    abort("cost must be non-negative")
  }
  if cost == 0.0 {
    information_gain
  } else {
    information_gain / cost
  }
}
