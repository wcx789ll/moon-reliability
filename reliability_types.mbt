///|
/// The observation status used by survival and reliability estimators.
pub(all) enum ObservationStatus {
  Failed
  RightCensored
  LeftCensored
  IntervalCensored
} derive(Debug, Eq)

///|
/// A single lifetime record. `time` is measured in the caller's unit.
pub struct LifeObservation {
  time : Double
  status : ObservationStatus
  cause : Int
  weight : Double
}

///|
/// Create an uncensored failure observation.
pub fn failure(time : Double) -> LifeObservation {
  { time, status: Failed, cause: 0, weight: 1.0 }
}

///|
/// Create a right-censored observation, for example a unit still running at
/// the end of a test or a customer who left the service before failure.
pub fn right_censored(time : Double) -> LifeObservation {
  { time, status: RightCensored, cause: 0, weight: 1.0 }
}

///|
/// Create a left-censored observation for a unit already failed at inspection.
pub fn left_censored(time : Double) -> LifeObservation {
  { time, status: LeftCensored, cause: 0, weight: 1.0 }
}

///|
/// Create an interval-censored observation. The interval is represented by
/// the midpoint for rank-based estimators; use `interval_record` when bounds
/// must be retained for an interval likelihood.
pub fn interval_censored(lower : Double, upper : Double) -> LifeObservation {
  if lower < 0.0 || upper < lower {
    abort("invalid censoring interval")
  }
  {
    time: (lower + upper) / 2.0,
    status: IntervalCensored,
    cause: 0,
    weight: 1.0,
  }
}

///|
/// A record that retains both endpoints of an inspection interval.
pub struct IntervalRecord {
  lower : Double
  upper : Double
  status : ObservationStatus
  weight : Double
}

///|
pub fn interval_record(lower : Double, upper : Double) -> IntervalRecord {
  if lower < 0.0 || upper < lower {
    abort("invalid censoring interval")
  }
  { lower, upper, status: IntervalCensored, weight: 1.0 }
}

///|
/// Attach a failure cause and sampling weight to an observation.
pub fn LifeObservation::with_metadata(
  self : LifeObservation,
  cause~ : Int,
  weight~ : Double,
) -> LifeObservation {
  if cause < 0 || weight <= 0.0 {
    abort("cause must be non-negative and weight must be positive")
  }
  { ..self, cause, weight }
}

///|
pub fn LifeObservation::is_failure(self : LifeObservation) -> Bool {
  self.status is Failed
}

///|
pub fn LifeObservation::is_censored(self : LifeObservation) -> Bool {
  !self.is_failure()
}

///|
/// Summary statistics returned by `summarize`.
pub struct SampleSummary {
  count : Int
  failures : Int
  censored : Int
  total_weight : Double
  mean : Double
  variance : Double
  standard_deviation : Double
  minimum : Double
  maximum : Double
  median : Double
}

///|
pub fn empty_sample_summary() -> SampleSummary {
  {
    count: 0,
    failures: 0,
    censored: 0,
    total_weight: 0.0,
    mean: 0.0,
    variance: 0.0,
    standard_deviation: 0.0,
    minimum: 0.0,
    maximum: 0.0,
    median: 0.0,
  }
}

///|
/// One step of a non-parametric survival curve.
pub struct SurvivalPoint {
  time : Double
  at_risk : Int
  events : Int
  censored : Int
  survival : Double
  standard_error : Double
  cumulative_hazard : Double
}

///|
pub fn survival_point(
  time~ : Double,
  at_risk~ : Int,
  events~ : Int,
  censored~ : Int,
  survival~ : Double,
  standard_error~ : Double,
  cumulative_hazard~ : Double,
) -> SurvivalPoint {
  {
    time,
    at_risk,
    events,
    censored,
    survival,
    standard_error,
    cumulative_hazard,
  }
}

///|
/// Result of a distribution fit.
pub struct FitResult {
  distribution : String
  parameters : Array[Double]
  log_likelihood : Double
  aic : Double
  bic : Double
  iterations : Int
  converged : Bool
  standard_errors : Array[Double]
}

///|
pub fn fit_result(
  distribution~ : String,
  parameters~ : Array[Double],
  log_likelihood~ : Double,
  aic~ : Double,
  bic~ : Double,
  iterations~ : Int,
  converged~ : Bool,
  standard_errors~ : Array[Double],
) -> FitResult {
  {
    distribution,
    parameters,
    log_likelihood,
    aic,
    bic,
    iterations,
    converged,
    standard_errors,
  }
}

///|
/// A point estimate and confidence interval for a reliability metric.
pub struct MetricEstimate {
  estimate : Double
  lower : Double
  upper : Double
  confidence_level : Double
}

///|
pub fn metric_estimate(
  estimate~ : Double,
  lower~ : Double,
  upper~ : Double,
  confidence_level~ : Double,
) -> MetricEstimate {
  { estimate, lower, upper, confidence_level }
}

///|
/// A small result type used by deterministic benchmark helpers.
pub struct BenchmarkResult {
  name : String
  iterations : Int
  elapsed_micros : Int64
  checksum : Double
  operations_per_second : Double
}

///|
pub fn benchmark_result(
  name~ : String,
  iterations~ : Int,
  elapsed_micros~ : Int64,
  checksum~ : Double,
  operations_per_second~ : Double,
) -> BenchmarkResult {
  { name, iterations, elapsed_micros, checksum, operations_per_second }
}

///|
/// Validate a lifetime record and return a descriptive error string, or None.
pub fn validate_observation(record : LifeObservation) -> String? {
  if record.time < 0.0 {
    Some("time must be non-negative")
  } else if record.weight <= 0.0 {
    Some("weight must be positive")
  } else if record.cause < 0 {
    Some("cause must be non-negative")
  } else {
    None
  }
}

///|
/// Validate a data set before passing it to an estimator.
pub fn validate_dataset(records : Array[LifeObservation]) -> Array[String] {
  let errors : Array[String] = []
  records.eachi((i, record) => {
    let validation = validate_observation(record)
    match validation {
      Some(message) => errors.push("record[\{i}]: \{message}")
      None => ()
    }
  })
  errors
}

///|
/// Return a copy of records sorted by observed time, preserving equal-time
/// observations for tied-event estimators.
pub fn sort_observations(
  records : Array[LifeObservation],
) -> Array[LifeObservation] {
  let result = records.copy()
  result.sort_by((a, b) => {
    if a.time < b.time {
      -1
    } else if a.time > b.time {
      1
    } else {
      0
    }
  })
  result
}

///|
pub fn clamp_probability(p : Double) -> Double {
  if p < 0.0 {
    0.0
  } else if p > 1.0 {
    1.0
  } else {
    p
  }
}

///|
pub fn safe_log_probability(p : Double) -> Double {
  if p <= 1.0e-300 {
    @math.ln(1.0e-300)
  } else {
    @math.ln(p)
  }
}

///|
pub fn finite_or(value : Double, fallback~ : Double) -> Double {
  if value != value {
    fallback
  } else {
    value
  }
}
