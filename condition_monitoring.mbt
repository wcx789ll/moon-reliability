///|
/// Signal class for condition-monitoring channels.
pub(all) enum ReliabilitySignalKind {
  ReliabilityVibration
  ReliabilityTemperature
  ReliabilityPressure
  ReliabilityCurrent
  ReliabilityAcoustic
  ReliabilityCounter
} derive(Debug, Eq)

///|
/// Health state used by an operational monitoring service.
pub(all) enum ReliabilityHealthState {
  ReliabilityHealthy
  ReliabilityWatch
  ReliabilityAlert
  ReliabilityCritical
  ReliabilityUnknown
} derive(Debug, Eq)

///|
/// Sensor metadata and acceptance limits.
pub struct ReliabilitySensor {
  sensor_id : String
  asset_id : Int
  kind : ReliabilitySignalKind
  unit : String
  lower_limit : Double
  upper_limit : Double
  calibration_scale : Double
  calibration_offset : Double
  sample_period : Double
  enabled : Bool
}

///|
pub fn reliability_sensor(
  sensor_id : String,
  asset_id : Int,
  kind : ReliabilitySignalKind,
  unit : String,
  lower_limit : Double,
  upper_limit : Double,
  calibration_scale : Double,
  calibration_offset : Double,
  sample_period : Double,
  enabled : Bool,
) -> ReliabilitySensor {
  if asset_id < 0 ||
    upper_limit < lower_limit ||
    calibration_scale == 0.0 ||
    sample_period <= 0.0 {
    abort("invalid reliability sensor")
  }
  {
    sensor_id,
    asset_id,
    kind,
    unit,
    lower_limit,
    upper_limit,
    calibration_scale,
    calibration_offset,
    sample_period,
    enabled,
  }
}

///|
pub fn reliability_sensor_calibrate(
  sensor : ReliabilitySensor,
  raw : Double,
) -> Double {
  raw * sensor.calibration_scale + sensor.calibration_offset
}

///|
pub fn reliability_sensor_is_in_limit(
  sensor : ReliabilitySensor,
  value : Double,
) -> Bool {
  value >= sensor.lower_limit && value <= sensor.upper_limit
}

///|
pub fn reliability_sensor_limit_fraction(
  sensor : ReliabilitySensor,
  value : Double,
) -> Double {
  if sensor.upper_limit == sensor.lower_limit {
    0.0
  } else {
    ((value - sensor.lower_limit) / (sensor.upper_limit - sensor.lower_limit))
    .max(0.0)
    .min(1.0)
  }
}

///|
pub fn reliability_sensor_margin(
  sensor : ReliabilitySensor,
  value : Double,
) -> Double {
  (value - sensor.lower_limit).min(sensor.upper_limit - value)
}

///|
pub fn reliability_sensor_expected_samples(
  sensor : ReliabilitySensor,
  duration : Double,
) -> Int {
  if duration <= 0.0 {
    0
  } else {
    (duration / sensor.sample_period).floor().to_int() + 1
  }
}

///|
/// Calibrated sensor reading with provenance and quality weight.
pub struct ReliabilityReading {
  sensor_id : String
  asset_id : Int
  timestamp : Double
  raw_value : Double
  value : Double
  quality : Double
  sequence : Int
}

///|
pub fn reliability_reading(
  sensor : ReliabilitySensor,
  timestamp : Double,
  raw_value : Double,
  quality : Double,
  sequence : Int,
) -> ReliabilityReading {
  if timestamp < 0.0 || quality < 0.0 || quality > 1.0 || sequence < 0 {
    abort("invalid reliability reading")
  }
  {
    sensor_id: sensor.sensor_id,
    asset_id: sensor.asset_id,
    timestamp,
    raw_value,
    value: reliability_sensor_calibrate(sensor, raw_value),
    quality,
    sequence,
  }
}

///|
pub fn reliability_reading_is_usable(reading : ReliabilityReading) -> Bool {
  reading.quality > 0.0
}

///|
pub fn reliability_reading_weighted_value(
  reading : ReliabilityReading,
) -> Double {
  reading.value * reading.quality
}

///|
pub fn reliability_reading_gap(
  previous : ReliabilityReading,
  current : ReliabilityReading,
) -> Double {
  (current.timestamp - previous.timestamp).max(0.0)
}

///|
pub fn reliability_reading_rate(
  previous : ReliabilityReading,
  current : ReliabilityReading,
) -> Double {
  let gap = current.timestamp - previous.timestamp
  if gap <= 0.0 {
    0.0
  } else {
    (current.value - previous.value) / gap
  }
}

///|
pub fn reliability_readings_sorted(
  readings : Array[ReliabilityReading],
) -> Array[ReliabilityReading] {
  let result = readings.copy()
  result.sort_by((left, right) => {
    if left.timestamp < right.timestamp {
      -1
    } else if left.timestamp > right.timestamp {
      1
    } else {
      0
    }
  })
  result
}

///|
pub fn reliability_readings_values(
  readings : Array[ReliabilityReading],
) -> Array[Double] {
  readings.filter_map(reading => {
    if reliability_reading_is_usable(reading) {
      Some(reading.value)
    } else {
      None
    }
  })
}

///|
pub fn reliability_readings_mean(
  readings : Array[ReliabilityReading],
) -> Double {
  let values = reliability_readings_values(readings)
  if values.is_empty() {
    0.0
  } else {
    mean(values)
  }
}

///|
pub fn reliability_readings_variance(
  readings : Array[ReliabilityReading],
) -> Double {
  let values = reliability_readings_values(readings)
  if values.length() < 2 {
    0.0
  } else {
    variance(values)
  }
}

///|
pub fn reliability_readings_range(
  readings : Array[ReliabilityReading],
) -> Double {
  let values = reliability_readings_values(readings)
  if values.is_empty() {
    0.0
  } else {
    max_value(values) - min_value(values)
  }
}

///|
pub fn reliability_readings_slope(
  readings : Array[ReliabilityReading],
) -> Double {
  let ordered = reliability_readings_sorted(readings)
  if ordered.length() < 2 {
    0.0
  } else {
    let first = ordered[0]
    let last = ordered[ordered.length() - 1]
    let duration = last.timestamp - first.timestamp
    if duration <= 0.0 {
      0.0
    } else {
      (last.value - first.value) / duration
    }
  }
}

///|
pub fn reliability_readings_missing_fraction(
  readings : Array[ReliabilityReading],
  start : Double,
  end : Double,
  expected_period : Double,
) -> Double {
  if end <= start || expected_period <= 0.0 {
    0.0
  } else {
    let expected = ((end - start) / expected_period).floor().to_int() + 1
    if expected == 0 {
      0.0
    } else {
      (expected - readings.length()).max(0).to_double() / expected.to_double()
    }
  }
}

///|
/// A derived health feature calculated from a signal window.
pub struct ReliabilityHealthFeature {
  name : String
  value : Double
  baseline : Double
  scale : Double
  weight : Double
  direction : Double
}

///|
pub fn reliability_health_feature(
  name : String,
  value : Double,
  baseline : Double,
  scale : Double,
  weight : Double,
  direction : Double,
) -> ReliabilityHealthFeature {
  if scale <= 0.0 || weight < 0.0 || direction == 0.0 {
    abort("invalid health feature")
  }
  { name, value, baseline, scale, weight, direction }
}

///|
pub fn reliability_health_feature_score(
  feature : ReliabilityHealthFeature,
) -> Double {
  let deviation = feature.direction *
    (feature.value - feature.baseline) /
    feature.scale
  (1.0 - deviation.abs()).max(0.0).min(1.0)
}

///|
pub fn reliability_health_feature_risk(
  feature : ReliabilityHealthFeature,
) -> Double {
  1.0 - reliability_health_feature_score(feature)
}

///|
pub fn reliability_health_feature_contribution(
  feature : ReliabilityHealthFeature,
) -> Double {
  feature.weight * reliability_health_feature_risk(feature)
}

///|
pub fn reliability_health_index(
  features : Array[ReliabilityHealthFeature],
) -> Double {
  if features.is_empty() {
    1.0
  } else {
    let total_weight = features.fold(init=0.0, (sum, feature) => {
      sum + feature.weight
    })
    if total_weight == 0.0 {
      1.0
    } else {
      features.fold(init=0.0, (sum, feature) => {
        sum + feature.weight * reliability_health_feature_score(feature)
      }) /
      total_weight
    }
  }
}

///|
pub fn reliability_health_risk_index(
  features : Array[ReliabilityHealthFeature],
) -> Double {
  1.0 - reliability_health_index(features)
}

///|
/// Health classification policy with explicit escalation thresholds.
pub struct ReliabilityHealthPolicy {
  watch_threshold : Double
  alert_threshold : Double
  critical_threshold : Double
  minimum_quality : Double
  persistence : Int
}

///|
pub fn reliability_health_policy(
  watch_threshold : Double,
  alert_threshold : Double,
  critical_threshold : Double,
  minimum_quality : Double,
  persistence : Int,
) -> ReliabilityHealthPolicy {
  if watch_threshold < 0.0 ||
    alert_threshold < watch_threshold ||
    critical_threshold < alert_threshold ||
    critical_threshold > 1.0 ||
    minimum_quality < 0.0 ||
    minimum_quality > 1.0 ||
    persistence < 1 {
    abort("invalid health policy")
  }
  {
    watch_threshold,
    alert_threshold,
    critical_threshold,
    minimum_quality,
    persistence,
  }
}

///|
pub fn reliability_health_state(
  policy : ReliabilityHealthPolicy,
  risk : Double,
  quality : Double,
) -> ReliabilityHealthState {
  if quality < policy.minimum_quality {
    ReliabilityHealthState::ReliabilityUnknown
  } else if risk >= policy.critical_threshold {
    ReliabilityHealthState::ReliabilityCritical
  } else if risk >= policy.alert_threshold {
    ReliabilityHealthState::ReliabilityAlert
  } else if risk >= policy.watch_threshold {
    ReliabilityHealthState::ReliabilityWatch
  } else {
    ReliabilityHealthState::ReliabilityHealthy
  }
}

///|
pub fn reliability_health_state_is_actionable(
  state : ReliabilityHealthState,
) -> Bool {
  state is ReliabilityAlert ||
  state is ReliabilityCritical ||
  state is ReliabilityUnknown
}

///|
pub fn reliability_health_state_rank(state : ReliabilityHealthState) -> Int {
  match state {
    ReliabilityHealthy => 0
    ReliabilityWatch => 1
    ReliabilityAlert => 2
    ReliabilityCritical => 3
    ReliabilityUnknown => 4
  }
}

///|
/// Asset-level condition assessment with a traceable feature vector.
pub struct ReliabilityConditionAssessment {
  asset_id : Int
  timestamp : Double
  index : Double
  risk : Double
  quality : Double
  state : ReliabilityHealthState
  features : Array[ReliabilityHealthFeature]
  evidence_count : Int
}

///|
pub fn reliability_condition_assessment(
  asset_id : Int,
  timestamp : Double,
  features : Array[ReliabilityHealthFeature],
  quality : Double,
  policy : ReliabilityHealthPolicy,
) -> ReliabilityConditionAssessment {
  if asset_id < 0 || timestamp < 0.0 || quality < 0.0 || quality > 1.0 {
    abort("invalid condition assessment")
  }
  let index = reliability_health_index(features)
  let risk = 1.0 - index
  {
    asset_id,
    timestamp,
    index,
    risk,
    quality,
    state: reliability_health_state(policy, risk, quality),
    features,
    evidence_count: features.length(),
  }
}

///|
pub fn reliability_assessment_is_healthy(
  assessment : ReliabilityConditionAssessment,
) -> Bool {
  assessment.state is ReliabilityHealthy
}

///|
pub fn reliability_assessment_risk(
  assessment : ReliabilityConditionAssessment,
) -> Double {
  assessment.risk
}

///|
pub fn reliability_assessment_top_feature(
  assessment : ReliabilityConditionAssessment,
) -> String {
  if assessment.features.is_empty() {
    "none"
  } else {
    let mut best = 0
    for i in 1..<assessment.features.length() {
      if reliability_health_feature_contribution(assessment.features[i]) >
        reliability_health_feature_contribution(assessment.features[best]) {
        best = i
      }
    }
    assessment.features[best].name
  }
}

///|
/// A persistence-aware alarm decision.
pub struct ReliabilityAlarmDecision {
  asset_id : Int
  state : ReliabilityHealthState
  consecutive_actionable : Int
  escalated : Bool
  reason : String
}

///|
pub fn reliability_alarm_decision(
  assessment : ReliabilityConditionAssessment,
  consecutive_actionable : Int,
  policy : ReliabilityHealthPolicy,
) -> ReliabilityAlarmDecision {
  if consecutive_actionable < 0 {
    abort("consecutive count must be non-negative")
  }
  let escalated = reliability_health_state_is_actionable(assessment.state) &&
    consecutive_actionable >= policy.persistence
  let reason = if escalated {
    "persistent actionable condition"
  } else if reliability_health_state_is_actionable(assessment.state) {
    "condition requires confirmation"
  } else {
    "within operating envelope"
  }
  {
    asset_id: assessment.asset_id,
    state: assessment.state,
    consecutive_actionable,
    escalated,
    reason,
  }
}

///|
pub fn reliability_alarm_needs_dispatch(
  decision : ReliabilityAlarmDecision,
) -> Bool {
  decision.escalated
}

///|
pub fn reliability_alarm_priority(decision : ReliabilityAlarmDecision) -> Int {
  if !decision.escalated {
    0
  } else {
    reliability_health_state_rank(decision.state)
  }
}

///|
/// Remaining useful life estimate from a health trajectory.
pub struct ReliabilityRulEstimate {
  asset_id : Int
  current_age : Double
  estimated_rul : Double
  lower_rul : Double
  upper_rul : Double
  confidence : Double
  slope : Double
}

///|
pub fn reliability_rul_estimate(
  asset_id : Int,
  current_age : Double,
  estimated_rul : Double,
  lower_rul : Double,
  upper_rul : Double,
  confidence : Double,
  slope : Double,
) -> ReliabilityRulEstimate {
  if asset_id < 0 ||
    current_age < 0.0 ||
    estimated_rul < 0.0 ||
    lower_rul < 0.0 ||
    upper_rul < lower_rul ||
    confidence <= 0.0 ||
    confidence >= 1.0 {
    abort("invalid RUL estimate")
  }
  {
    asset_id,
    current_age,
    estimated_rul,
    lower_rul,
    upper_rul,
    confidence,
    slope,
  }
}

///|
pub fn reliability_rul_from_linear_health(
  asset_id : Int,
  current_age : Double,
  health : Double,
  health_rate : Double,
  target_health : Double,
  uncertainty : Double,
) -> ReliabilityRulEstimate {
  if health_rate >= 0.0 ||
    uncertainty < 0.0 ||
    target_health < 0.0 ||
    target_health > 1.0 {
    abort("invalid linear RUL input")
  }
  let rul = ((target_health - health) / health_rate).max(0.0)
  reliability_rul_estimate(
    asset_id,
    current_age,
    rul,
    (rul - uncertainty).max(0.0),
    rul + uncertainty,
    0.9,
    health_rate,
  )
}

///|
pub fn reliability_rul_is_due(
  estimate : ReliabilityRulEstimate,
  horizon : Double,
) -> Bool {
  horizon >= 0.0 && estimate.estimated_rul <= horizon
}

///|
pub fn reliability_rul_conservative(
  estimate : ReliabilityRulEstimate,
) -> Double {
  estimate.lower_rul
}

///|
pub fn reliability_rul_margin(estimate : ReliabilityRulEstimate) -> Double {
  estimate.upper_rul - estimate.lower_rul
}

///|
pub fn reliability_condition_batch_risk(
  assessments : Array[ReliabilityConditionAssessment],
) -> Double {
  if assessments.is_empty() {
    0.0
  } else {
    assessments.fold(init=0.0, (sum, assessment) => sum + assessment.risk) /
    assessments.length().to_double()
  }
}

///|
pub fn reliability_condition_actionable_assets(
  assessments : Array[ReliabilityConditionAssessment],
) -> Array[Int] {
  assessments.filter_map(assessment => {
    if reliability_health_state_is_actionable(assessment.state) {
      Some(assessment.asset_id)
    } else {
      None
    }
  })
}

///|
pub fn reliability_condition_ranked_assets(
  assessments : Array[ReliabilityConditionAssessment],
) -> Array[ReliabilityConditionAssessment] {
  let result = assessments.copy()
  result.sort_by((left, right) => {
    if left.risk > right.risk {
      -1
    } else if left.risk < right.risk {
      1
    } else {
      0
    }
  })
  result
}

///|
pub fn reliability_condition_coverage(
  assessments : Array[ReliabilityConditionAssessment],
  total_assets : Int,
) -> Double {
  if total_assets <= 0 {
    0.0
  } else {
    assessments.length().to_double() / total_assets.to_double()
  }
}

///|
pub fn reliability_condition_checksum(
  assessments : Array[ReliabilityConditionAssessment],
) -> Double {
  reliability_condition_batch_risk(assessments) * 100.0 +
  assessments.fold(init=0.0, (sum, assessment) => {
    sum + assessment.asset_id.to_double() + assessment.index
  })
}
