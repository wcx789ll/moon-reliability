///|
/// A software reliability growth model configuration.
pub(all) enum SoftwareGrowthLaw {
  SoftwareExponential
  SoftwareMusaOkumoto
  SoftwareWeibull
  SoftwareGompertz
} derive(Debug, Eq)

///|
pub struct SoftwareReliabilityModel {
  law : SoftwareGrowthLaw
  initial_defects : Double
  scale : Double
  shape : Double
  detection_efficiency : Double
  name : String
}

///|
pub fn software_reliability_model(
  law : SoftwareGrowthLaw,
  initial_defects : Double,
  scale : Double,
  shape : Double,
  detection_efficiency : Double,
  name : String,
) -> SoftwareReliabilityModel {
  if initial_defects < 0.0 ||
    scale <= 0.0 ||
    shape <= 0.0 ||
    detection_efficiency <= 0.0 ||
    detection_efficiency > 1.0 {
    abort("invalid software reliability model")
  }
  { law, initial_defects, scale, shape, detection_efficiency, name }
}

///|
pub fn software_expected_failures(
  model : SoftwareReliabilityModel,
  exposure : Double,
) -> Double {
  if exposure < 0.0 {
    abort("software exposure must be non-negative")
  }
  match model.law {
    SoftwareExponential =>
      model.initial_defects * (1.0 - @math.exp(-exposure / model.scale))
    SoftwareMusaOkumoto =>
      model.scale *
      @math.ln(1.0 + exposure / model.scale) *
      model.detection_efficiency
    SoftwareWeibull =>
      model.initial_defects *
      (1.0 - @math.exp(-@math.pow(exposure / model.scale, model.shape)))
    SoftwareGompertz =>
      model.initial_defects *
      (
        1.0 -
        @math.exp(-model.scale * (@math.exp(model.shape * exposure) - 1.0))
      )
  }
}

///|
pub fn software_remaining_defects(
  model : SoftwareReliabilityModel,
  exposure : Double,
) -> Double {
  (model.initial_defects - software_expected_failures(model, exposure)).max(0.0)
}

///|
pub fn software_failure_intensity(
  model : SoftwareReliabilityModel,
  exposure : Double,
) -> Double {
  if exposure < 0.0 {
    abort("software exposure must be non-negative")
  }
  match model.law {
    SoftwareExponential =>
      model.initial_defects / model.scale * @math.exp(-exposure / model.scale)
    SoftwareMusaOkumoto =>
      model.scale / (model.scale + exposure) * model.detection_efficiency
    SoftwareWeibull =>
      if exposure == 0.0 && model.shape < 1.0 {
        1.0e300
      } else {
        model.initial_defects *
        model.shape /
        model.scale *
        @math.pow(exposure / model.scale, model.shape - 1.0) *
        @math.exp(-@math.pow(exposure / model.scale, model.shape))
      }
    SoftwareGompertz =>
      model.initial_defects *
      model.scale *
      model.shape *
      @math.exp(model.shape * exposure) *
      @math.exp(-model.scale * (@math.exp(model.shape * exposure) - 1.0))
  }
}

///|
pub fn software_failure_rate_per_hour(
  model : SoftwareReliabilityModel,
  exposure : Double,
) -> Double {
  software_failure_intensity(model, exposure) /
  software_remaining_defects(model, exposure).max(1.0e-12)
}

///|
pub fn software_mean_time_between_failures(
  model : SoftwareReliabilityModel,
  exposure : Double,
) -> Double {
  1.0 / software_failure_intensity(model, exposure).max(1.0e-300)
}

///|
pub fn software_reliability(
  model : SoftwareReliabilityModel,
  mission_exposure : Double,
  current_exposure : Double,
) -> Double {
  if mission_exposure < 0.0 || current_exposure < 0.0 {
    abort("exposure must be non-negative")
  }
  @math.exp(
    -software_failure_intensity(model, current_exposure) * mission_exposure,
  )
}

///|
pub fn software_cumulative_intensity(
  model : SoftwareReliabilityModel,
  exposure : Double,
) -> Double {
  software_expected_failures(model, exposure)
}

///|
pub fn software_growth_efficiency(
  model : SoftwareReliabilityModel,
  exposure : Double,
) -> Double {
  if model.initial_defects == 0.0 {
    1.0
  } else {
    software_expected_failures(model, exposure) / model.initial_defects
  }
}

///|
pub fn software_defect_density(
  model : SoftwareReliabilityModel,
  code_size : Double,
  exposure : Double,
) -> Double {
  if code_size <= 0.0 {
    abort("code size must be positive")
  }
  software_remaining_defects(model, exposure) / code_size
}

///|
pub fn software_defects_removed(
  model : SoftwareReliabilityModel,
  exposure : Double,
) -> Double {
  software_expected_failures(model, exposure)
}

///|
pub struct SoftwareFailureRecord {
  time : Double
  severity : Int
  detection_cost : Double
  corrected : Bool
  component : Int
}

///|
pub fn software_failure_record(
  time : Double,
  severity : Int,
  detection_cost : Double,
  corrected : Bool,
  component : Int,
) -> SoftwareFailureRecord {
  if time < 0.0 || severity < 0 || detection_cost < 0.0 || component < 0 {
    abort("invalid software failure record")
  }
  { time, severity, detection_cost, corrected, component }
}

///|
pub fn software_record_count(records : Array[SoftwareFailureRecord]) -> Int {
  records.length()
}

///|
pub fn software_record_total_cost(
  records : Array[SoftwareFailureRecord],
) -> Double {
  records.fold(init=0.0, (total, record) => total + record.detection_cost)
}

///|
pub fn software_record_mean_time(
  records : Array[SoftwareFailureRecord],
) -> Double {
  if records.is_empty() {
    0.0
  } else {
    mean(records.map(record => record.time))
  }
}

///|
pub fn software_record_median_time(
  records : Array[SoftwareFailureRecord],
) -> Double {
  if records.is_empty() {
    0.0
  } else {
    quantile(records.map(record => record.time), 0.5)
  }
}

///|
pub fn software_record_total_severity(
  records : Array[SoftwareFailureRecord],
) -> Int {
  records.fold(init=0, (total, record) => total + record.severity)
}

///|
pub fn software_record_corrected_count(
  records : Array[SoftwareFailureRecord],
) -> Int {
  records.fold(init=0, (total, record) => {
    if record.corrected {
      total + 1
    } else {
      total
    }
  })
}

///|
pub fn software_record_correction_fraction(
  records : Array[SoftwareFailureRecord],
) -> Double {
  if records.is_empty() {
    0.0
  } else {
    software_record_corrected_count(records).to_double() /
    records.length().to_double()
  }
}

///|
pub fn software_record_failure_rate(
  records : Array[SoftwareFailureRecord],
  exposure : Double,
) -> Double {
  if exposure <= 0.0 {
    abort("exposure must be positive")
  }
  records.length().to_double() / exposure
}

///|
pub fn software_record_severity_rate(
  records : Array[SoftwareFailureRecord],
  exposure : Double,
) -> Double {
  if exposure <= 0.0 {
    abort("exposure must be positive")
  }
  software_record_total_severity(records).to_double() / exposure
}

///|
pub fn software_records_by_component(
  records : Array[SoftwareFailureRecord],
  component : Int,
) -> Array[SoftwareFailureRecord] {
  records.filter(record => record.component == component)
}

///|
pub fn software_component_ids(
  records : Array[SoftwareFailureRecord],
) -> Array[Int] {
  let result = []
  for record in records {
    if !result.contains(record.component) {
      result.push(record.component)
    }
  }
  result.sort()
  result
}

///|
pub fn software_component_counts(
  records : Array[SoftwareFailureRecord],
) -> Array[Int] {
  software_component_ids(records).map(component => {
    software_records_by_component(records, component).length()
  })
}

///|
pub fn software_component_severity(
  records : Array[SoftwareFailureRecord],
) -> Array[Int] {
  software_component_ids(records).map(component => {
    software_records_by_component(records, component).fold(init=0, (
      total,
      record,
    ) => total + record.severity)
  })
}

///|
pub fn software_component_risk(
  records : Array[SoftwareFailureRecord],
) -> Array[Double] {
  let ids = software_component_ids(records)
  ids.map(component => {
    let group = software_records_by_component(records, component)
    group.fold(init=0.0, (total, record) => {
      total + record.severity.to_double() * (1.0 + record.detection_cost)
    })
  })
}

///|
pub fn software_component_rank(
  records : Array[SoftwareFailureRecord],
) -> Array[Int] {
  let ids = software_component_ids(records)
  ids.sort_by((left, right) => {
    let left_risk = software_records_by_component(records, left).fold(
      init=0.0,
      (total, record) => {
        total + record.severity.to_double() * (1.0 + record.detection_cost)
      },
    )
    let right_risk = software_records_by_component(records, right).fold(
      init=0.0,
      (total, record) => {
        total + record.severity.to_double() * (1.0 + record.detection_cost)
      },
    )
    if left_risk > right_risk {
      -1
    } else if left_risk < right_risk {
      1
    } else {
      0
    }
  })
  ids
}

///|
pub struct SoftwareReleaseGate {
  target_intensity : Double
  target_reliability : Double
  mission_exposure : Double
  maximum_severity : Int
  maximum_open_defects : Int
  minimum_correction_fraction : Double
}

///|
pub fn software_release_gate(
  target_intensity : Double,
  target_reliability : Double,
  mission_exposure : Double,
  maximum_severity : Int,
  maximum_open_defects : Int,
  minimum_correction_fraction : Double,
) -> SoftwareReleaseGate {
  if target_intensity < 0.0 ||
    target_reliability <= 0.0 ||
    target_reliability > 1.0 ||
    mission_exposure <= 0.0 ||
    maximum_severity < 0 ||
    maximum_open_defects < 0 ||
    minimum_correction_fraction < 0.0 ||
    minimum_correction_fraction > 1.0 {
    abort("invalid release gate")
  }
  {
    target_intensity,
    target_reliability,
    mission_exposure,
    maximum_severity,
    maximum_open_defects,
    minimum_correction_fraction,
  }
}

///|
pub fn software_release_gate_intensity_passes(
  gate : SoftwareReleaseGate,
  model : SoftwareReliabilityModel,
  current_exposure : Double,
) -> Bool {
  software_failure_intensity(model, current_exposure) <= gate.target_intensity
}

///|
pub fn software_release_gate_reliability_passes(
  gate : SoftwareReleaseGate,
  model : SoftwareReliabilityModel,
  current_exposure : Double,
) -> Bool {
  software_reliability(model, gate.mission_exposure, current_exposure) >=
  gate.target_reliability
}

///|
pub fn software_release_gate_records_pass(
  gate : SoftwareReleaseGate,
  records : Array[SoftwareFailureRecord],
) -> Bool {
  software_record_total_severity(records) <= gate.maximum_severity &&
  records.length() <= gate.maximum_open_defects &&
  software_record_correction_fraction(records) >=
  gate.minimum_correction_fraction
}

///|
pub fn software_release_decision(
  gate : SoftwareReleaseGate,
  model : SoftwareReliabilityModel,
  current_exposure : Double,
  records : Array[SoftwareFailureRecord],
) -> String {
  if !software_release_gate_intensity_passes(gate, model, current_exposure) {
    "reject-intensity"
  } else if !software_release_gate_reliability_passes(
      gate, model, current_exposure,
    ) {
    "reject-reliability"
  } else if !software_release_gate_records_pass(gate, records) {
    "reject-quality"
  } else {
    "release"
  }
}

///|
pub fn software_release_score(
  gate : SoftwareReleaseGate,
  model : SoftwareReliabilityModel,
  current_exposure : Double,
  records : Array[SoftwareFailureRecord],
) -> Double {
  let intensity_score = (gate.target_intensity /
  software_failure_intensity(model, current_exposure).max(1.0e-300)).min(1.0)
  let reliability_score = (software_reliability(
    model,
    gate.mission_exposure,
    current_exposure,
  ) /
  gate.target_reliability).min(1.0)
  let quality_score = if software_record_total_severity(records) == 0 {
    1.0
  } else {
    (gate.maximum_severity.to_double() /
    software_record_total_severity(records).to_double()).min(1.0)
  }
  (0.4 * intensity_score + 0.4 * reliability_score + 0.2 * quality_score).min(
    1.0,
  )
}

///|
pub fn software_release_label(score : Double) -> String {
  if score >= 0.9 {
    "ready"
  } else if score >= 0.7 {
    "review"
  } else {
    "not-ready"
  }
}

///|
pub struct SoftwareTestSession {
  session_id : Int
  start : Double
  end : Double
  executed_cases : Int
  failed_cases : Int
  failures : Array[SoftwareFailureRecord]
}

///|
pub fn software_test_session(
  session_id : Int,
  start : Double,
  end : Double,
  executed_cases : Int,
  failed_cases : Int,
  failures : Array[SoftwareFailureRecord],
) -> SoftwareTestSession {
  if session_id < 0 ||
    end <= start ||
    executed_cases < 0 ||
    failed_cases < 0 ||
    failed_cases > executed_cases {
    abort("invalid software test session")
  }
  { session_id, start, end, executed_cases, failed_cases, failures }
}

///|
pub fn software_session_duration(session : SoftwareTestSession) -> Double {
  session.end - session.start
}

///|
pub fn software_session_case_pass_rate(session : SoftwareTestSession) -> Double {
  if session.executed_cases == 0 {
    0.0
  } else {
    (session.executed_cases - session.failed_cases).to_double() /
    session.executed_cases.to_double()
  }
}

///|
pub fn software_session_failure_rate(session : SoftwareTestSession) -> Double {
  if session.executed_cases == 0 {
    0.0
  } else {
    session.failed_cases.to_double() / session.executed_cases.to_double()
  }
}

///|
pub fn software_session_failure_density(
  session : SoftwareTestSession,
) -> Double {
  if session.executed_cases == 0 {
    0.0
  } else {
    session.failures.length().to_double() / session.executed_cases.to_double()
  }
}

///|
pub fn software_session_severity(session : SoftwareTestSession) -> Int {
  software_record_total_severity(session.failures)
}

///|
pub fn software_session_cost(session : SoftwareTestSession) -> Double {
  software_record_total_cost(session.failures)
}

///|
pub fn software_session_is_stable(
  session : SoftwareTestSession,
  maximum_failure_rate : Double,
) -> Bool {
  software_session_failure_rate(session) <= maximum_failure_rate
}

///|
pub fn software_session_checksum(session : SoftwareTestSession) -> Double {
  session.session_id.to_double() +
  session.start +
  session.end +
  session.executed_cases.to_double() +
  session.failed_cases.to_double() +
  software_session_severity(session).to_double()
}

///|
pub fn software_sessions_total_cases(
  sessions : Array[SoftwareTestSession],
) -> Int {
  sessions.fold(init=0, (total, session) => total + session.executed_cases)
}

///|
pub fn software_sessions_total_failures(
  sessions : Array[SoftwareTestSession],
) -> Int {
  sessions.fold(init=0, (total, session) => total + session.failed_cases)
}

///|
pub fn software_sessions_pass_rate(
  sessions : Array[SoftwareTestSession],
) -> Double {
  let cases = software_sessions_total_cases(sessions)
  if cases == 0 {
    0.0
  } else {
    (cases - software_sessions_total_failures(sessions)).to_double() /
    cases.to_double()
  }
}

///|
pub fn software_sessions_failure_rate(
  sessions : Array[SoftwareTestSession],
) -> Double {
  let cases = software_sessions_total_cases(sessions)
  if cases == 0 {
    0.0
  } else {
    software_sessions_total_failures(sessions).to_double() / cases.to_double()
  }
}

///|
pub fn software_sessions_duration(
  sessions : Array[SoftwareTestSession],
) -> Double {
  sessions.fold(init=0.0, (total, session) => {
    total + software_session_duration(session)
  })
}

///|
pub fn software_sessions_checksum(
  sessions : Array[SoftwareTestSession],
) -> Double {
  sessions.fold(init=0.0, (total, session) => {
    total + software_session_checksum(session)
  })
}

///|
pub fn software_model_fit(
  law : SoftwareGrowthLaw,
  records : Array[SoftwareFailureRecord],
  initial_defects : Double,
  scale : Double,
) -> SoftwareReliabilityModel {
  if records.is_empty() {
    abort("software model fit requires records")
  }
  let exposure = max_value(records.map(record => record.time)).max(1.0)
  let observed = records.length().to_double()
  let shape = if law is SoftwareWeibull {
    (observed / initial_defects.max(1.0)).max(0.1)
  } else {
    1.0
  }
  software_reliability_model(
    law,
    initial_defects.max(observed),
    scale.max(exposure),
    shape,
    1.0,
    "fitted",
  )
}

///|
pub fn software_model_rmse(
  model : SoftwareReliabilityModel,
  records : Array[SoftwareFailureRecord],
) -> Double {
  if records.is_empty() {
    0.0
  } else {
    let mut sum = 0.0
    for record in records {
      let prediction = software_expected_failures(model, record.time)
      sum += (prediction - 1.0) * (prediction - 1.0)
    }
    (sum / records.length().to_double()).sqrt()
  }
}

///|
pub fn software_model_aic(
  model : SoftwareReliabilityModel,
  records : Array[SoftwareFailureRecord],
) -> Double {
  2.0 * 5.0 +
  records.length().to_double() *
  @math.ln(software_model_rmse(model, records).max(1.0e-300))
}

///|
pub fn software_model_bic(
  model : SoftwareReliabilityModel,
  records : Array[SoftwareFailureRecord],
) -> Double {
  5.0 * @math.ln(records.length().to_double().max(1.0)) +
  records.length().to_double() *
  @math.ln(software_model_rmse(model, records).max(1.0e-300))
}

///|
pub fn software_model_compare(
  models : Array[SoftwareReliabilityModel],
  records : Array[SoftwareFailureRecord],
) -> Array[Double] {
  models.map(model => software_model_rmse(model, records))
}

///|
pub fn software_model_best(
  models : Array[SoftwareReliabilityModel],
  records : Array[SoftwareFailureRecord],
) -> SoftwareReliabilityModel {
  if models.is_empty() {
    abort("models must not be empty")
  }
  let mut best = models[0]
  for model in models[1:] {
    if software_model_rmse(model, records) < software_model_rmse(best, records) {
      best = model
    }
  }
  best
}

///|
pub fn software_model_checksum(model : SoftwareReliabilityModel) -> Double {
  model.initial_defects + model.scale + model.shape + model.detection_efficiency
}
