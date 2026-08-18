///|
/// Runtime observability primitives for services and production equipment.
/// The module turns timestamped measurements and incidents into reliability
/// indicators that can be used by dashboards, alerting, and planning code.
pub struct TelemetryPoint {
  timestamp : Double
  value : Double
  healthy : Bool
  weight : Double
}

///|
pub fn telemetry_point(
  timestamp~ : Double,
  value~ : Double,
  healthy~ : Bool,
  weight~ : Double,
) -> TelemetryPoint {
  if timestamp < 0.0 || weight <= 0.0 {
    abort("timestamp must be non-negative and weight must be positive")
  }
  { timestamp, value, healthy, weight }
}

///|
pub struct TelemetryWindow {
  points : Array[TelemetryPoint]
  start : Double
  end : Double
  interval : Double
}

///|
pub fn telemetry_window(
  points : Array[TelemetryPoint],
  start~ : Double,
  end~ : Double,
  interval~ : Double,
) -> TelemetryWindow {
  if start < 0.0 || end <= start || interval <= 0.0 {
    abort("invalid telemetry window")
  }
  let selected = points.filter(point => {
    point.timestamp >= start && point.timestamp <= end
  })
  { points: selected, start, end, interval }
}

///|
pub fn telemetry_window_duration(window : TelemetryWindow) -> Double {
  window.end - window.start
}

///|
pub fn telemetry_window_count(window : TelemetryWindow) -> Int {
  window.points.length()
}

///|
pub fn telemetry_window_values(window : TelemetryWindow) -> Array[Double] {
  window.points.map(point => point.value)
}

///|
pub fn telemetry_window_healthy_count(window : TelemetryWindow) -> Int {
  window.points.fold(init=0, (count, point) => {
    if point.healthy {
      count + 1
    } else {
      count
    }
  })
}

///|
pub fn telemetry_window_unhealthy_count(window : TelemetryWindow) -> Int {
  window.points.length() - telemetry_window_healthy_count(window)
}

///|
pub fn telemetry_window_weight(window : TelemetryWindow) -> Double {
  window.points.fold(init=0.0, (total, point) => total + point.weight)
}

///|
pub fn telemetry_window_mean(window : TelemetryWindow) -> Double {
  let weight = telemetry_window_weight(window)
  if weight <= 0.0 {
    0.0
  } else {
    window.points.fold(init=0.0, (total, point) => {
      total + point.value * point.weight
    }) /
    weight
  }
}

///|
pub fn telemetry_window_minimum(window : TelemetryWindow) -> Double {
  if window.points.is_empty() {
    0.0
  } else {
    let mut result = window.points[0].value
    for point in window.points {
      if point.value < result {
        result = point.value
      }
    }
    result
  }
}

///|
pub fn telemetry_window_maximum(window : TelemetryWindow) -> Double {
  if window.points.is_empty() {
    0.0
  } else {
    let mut result = window.points[0].value
    for point in window.points {
      if point.value > result {
        result = point.value
      }
    }
    result
  }
}

///|
pub fn telemetry_window_range(window : TelemetryWindow) -> Double {
  telemetry_window_maximum(window) - telemetry_window_minimum(window)
}

///|
pub fn telemetry_window_variance(window : TelemetryWindow) -> Double {
  let weight = telemetry_window_weight(window)
  if weight <= 0.0 {
    0.0
  } else {
    let center = telemetry_window_mean(window)
    window.points.fold(init=0.0, (total, point) => {
      total + point.weight * (point.value - center) * (point.value - center)
    }) /
    weight
  }
}

///|
pub fn telemetry_window_standard_deviation(window : TelemetryWindow) -> Double {
  telemetry_window_variance(window).sqrt()
}

///|
pub fn telemetry_window_availability(window : TelemetryWindow) -> Double {
  let total = telemetry_window_weight(window)
  if total <= 0.0 {
    0.0
  } else {
    window.points.fold(init=0.0, (value, point) => {
      if point.healthy {
        value + point.weight
      } else {
        value
      }
    }) /
    total
  }
}

///|
pub fn telemetry_window_failure_rate(window : TelemetryWindow) -> Double {
  1.0 - telemetry_window_availability(window)
}

///|
pub fn telemetry_window_coefficient_of_variation(
  window : TelemetryWindow,
) -> Double {
  let mean_value = telemetry_window_mean(window)
  if mean_value == 0.0 {
    0.0
  } else {
    telemetry_window_standard_deviation(window) / mean_value.abs()
  }
}

///|
pub fn telemetry_window_normalized(window : TelemetryWindow) -> Array[Double] {
  let mean_value = telemetry_window_mean(window)
  let deviation = telemetry_window_standard_deviation(window)
  if deviation <= 1.0e-12 {
    Array::make(window.points.length(), 0.0)
  } else {
    window.points.map(point => (point.value - mean_value) / deviation)
  }
}

///|
pub fn telemetry_window_threshold_count(
  window : TelemetryWindow,
  lower : Double,
  upper : Double,
) -> Int {
  if lower > upper {
    abort("lower threshold must not exceed upper threshold")
  }
  window.points.fold(init=0, (count, point) => {
    if point.value < lower || point.value > upper {
      count + 1
    } else {
      count
    }
  })
}

///|
pub fn telemetry_window_above(
  window : TelemetryWindow,
  threshold : Double,
) -> Int {
  window.points.fold(init=0, (count, point) => {
    if point.value > threshold {
      count + 1
    } else {
      count
    }
  })
}

///|
pub fn telemetry_window_below(
  window : TelemetryWindow,
  threshold : Double,
) -> Int {
  window.points.fold(init=0, (count, point) => {
    if point.value < threshold {
      count + 1
    } else {
      count
    }
  })
}

///|
pub fn telemetry_window_first(window : TelemetryWindow) -> Double {
  if window.points.is_empty() {
    window.start
  } else {
    window.points[0].timestamp
  }
}

///|
pub fn telemetry_window_last(window : TelemetryWindow) -> Double {
  if window.points.is_empty() {
    window.end
  } else {
    window.points[window.points.length() - 1].timestamp
  }
}

///|
pub fn telemetry_window_coverage(window : TelemetryWindow) -> Double {
  if window.points.is_empty() {
    0.0
  } else {
    ((telemetry_window_last(window) - telemetry_window_first(window)) /
    telemetry_window_duration(window))
    .max(0.0)
    .min(1.0)
  }
}

///|
pub fn telemetry_window_gap(window : TelemetryWindow) -> Double {
  if window.points.length() < 2 {
    telemetry_window_duration(window)
  } else {
    let mut gap = 0.0
    for i in 0..<(window.points.length() - 1) {
      gap = gap.max(window.points[i + 1].timestamp - window.points[i].timestamp)
    }
    gap
  }
}

///|
pub fn telemetry_window_event_count(window : TelemetryWindow) -> Int {
  if window.points.length() < 2 {
    0
  } else {
    let mut events = 0
    for i in 1..<window.points.length() {
      if window.points[i].healthy != window.points[i - 1].healthy {
        events += 1
      }
    }
    events
  }
}

///|
pub fn telemetry_window_downtime(window : TelemetryWindow) -> Double {
  telemetry_window_duration(window) * telemetry_window_failure_rate(window)
}

///|
pub fn telemetry_window_error_budget(
  window : TelemetryWindow,
  target : Double,
) -> Double {
  if target < 0.0 || target > 1.0 {
    abort("target must be between zero and one")
  }
  (telemetry_window_availability(window) - target).max(0.0) *
  telemetry_window_duration(window)
}

///|
pub fn telemetry_window_burn_rate(
  window : TelemetryWindow,
  target : Double,
) -> Double {
  if target >= 1.0 || target < 0.0 {
    abort("target must be between zero and one")
  }
  telemetry_window_failure_rate(window) / (1.0 - target)
}

///|
pub struct IncidentRecord {
  start : Double
  end : Double
  severity : Int
  cause : Int
}

///|
pub fn incident_record(
  start~ : Double,
  end~ : Double,
  severity~ : Int,
  cause~ : Int,
) -> IncidentRecord {
  if start < 0.0 || end < start || severity < 0 || cause < 0 {
    abort("invalid incident record")
  }
  { start, end, severity, cause }
}

///|
pub fn incident_duration(incident : IncidentRecord) -> Double {
  incident.end - incident.start
}

///|
pub fn incident_is_open_at(
  incident : IncidentRecord,
  timestamp : Double,
) -> Bool {
  timestamp >= incident.start && timestamp <= incident.end
}

///|
pub fn incident_overlaps(left : IncidentRecord, right : IncidentRecord) -> Bool {
  left.start <= right.end && right.start <= left.end
}

///|
pub fn incident_union_duration(incidents : Array[IncidentRecord]) -> Double {
  if incidents.is_empty() {
    0.0
  } else {
    let ordered = incidents.copy()
    ordered.sort_by((left, right) => {
      if left.start < right.start {
        -1
      } else if left.start > right.start {
        1
      } else {
        0
      }
    })
    let mut total = 0.0
    let mut start = ordered[0].start
    let mut end = ordered[0].end
    for incident in ordered[1:] {
      if incident.start <= end {
        end = end.max(incident.end)
      } else {
        total += end - start
        start = incident.start
        end = incident.end
      }
    }
    total + end - start
  }
}

///|
pub fn incident_total_duration(incidents : Array[IncidentRecord]) -> Double {
  incidents.fold(init=0.0, (total, incident) => {
    total + incident_duration(incident)
  })
}

///|
pub fn incident_mean_duration(incidents : Array[IncidentRecord]) -> Double {
  if incidents.is_empty() {
    0.0
  } else {
    incident_total_duration(incidents) / incidents.length().to_double()
  }
}

///|
pub fn incident_max_duration(incidents : Array[IncidentRecord]) -> Double {
  incidents.fold(init=0.0, (maximum, incident) => {
    maximum.max(incident_duration(incident))
  })
}

///|
pub fn incident_count_by_severity(
  incidents : Array[IncidentRecord],
  severity : Int,
) -> Int {
  incidents.fold(init=0, (count, incident) => {
    if incident.severity == severity {
      count + 1
    } else {
      count
    }
  })
}

///|
pub fn incident_count_by_cause(
  incidents : Array[IncidentRecord],
  cause : Int,
) -> Int {
  incidents.fold(init=0, (count, incident) => {
    if incident.cause == cause {
      count + 1
    } else {
      count
    }
  })
}

///|
pub fn incident_severity_weight(incidents : Array[IncidentRecord]) -> Double {
  incidents.fold(init=0.0, (total, incident) => {
    total + incident_duration(incident) * (incident.severity + 1).to_double()
  })
}

///|
pub fn incident_rate(
  incidents : Array[IncidentRecord],
  window : Double,
) -> Double {
  if window <= 0.0 {
    abort("window must be positive")
  }
  incidents.length().to_double() / window
}

///|
pub struct IncidentSummary {
  count : Int
  total_duration : Double
  union_duration : Double
  mean_duration : Double
  maximum_duration : Double
  severity_weight : Double
  rate : Double
}

///|
pub fn summarize_incidents(
  incidents : Array[IncidentRecord],
  window : Double,
) -> IncidentSummary {
  if window <= 0.0 {
    abort("window must be positive")
  }
  {
    count: incidents.length(),
    total_duration: incident_total_duration(incidents),
    union_duration: incident_union_duration(incidents),
    mean_duration: incident_mean_duration(incidents),
    maximum_duration: incident_max_duration(incidents),
    severity_weight: incident_severity_weight(incidents),
    rate: incident_rate(incidents, window),
  }
}

///|
pub fn incident_availability(
  incidents : Array[IncidentRecord],
  window : Double,
) -> Double {
  if window <= 0.0 {
    abort("window must be positive")
  }
  (1.0 - incident_union_duration(incidents) / window).max(0.0).min(1.0)
}

///|
pub fn incident_mttr(incidents : Array[IncidentRecord]) -> Double {
  incident_mean_duration(incidents)
}

///|
pub fn incident_mtbf(
  incidents : Array[IncidentRecord],
  window : Double,
) -> Double {
  if incidents.is_empty() {
    window
  } else {
    (window - incident_union_duration(incidents)).max(0.0) /
    incidents.length().to_double()
  }
}

///|
pub struct AlertRule {
  name : String
  threshold : Double
  direction : Int
  minimum_samples : Int
  consecutive_windows : Int
}

///|
pub fn alert_rule(
  name~ : String,
  threshold~ : Double,
  direction~ : Int,
  minimum_samples~ : Int,
  consecutive_windows~ : Int,
) -> AlertRule {
  if (direction != 1 && direction != -1) ||
    minimum_samples < 1 ||
    consecutive_windows < 1 {
    abort("invalid alert rule")
  }
  { name, threshold, direction, minimum_samples, consecutive_windows }
}

///|
pub fn alert_rule_breached(
  rule : AlertRule,
  value : Double,
  samples : Int,
) -> Bool {
  if samples < rule.minimum_samples {
    false
  } else if rule.direction > 0 {
    value >= rule.threshold
  } else {
    value <= rule.threshold
  }
}

///|
pub struct AlertDecision {
  rule_name : String
  triggered : Bool
  value : Double
  threshold : Double
  consecutive : Int
  severity : Int
}

///|
pub fn evaluate_alert(
  rule : AlertRule,
  values : Array[Double],
) -> AlertDecision {
  let mut consecutive = 0
  let mut maximum = 0.0
  for value in values {
    if alert_rule_breached(rule, value, values.length()) {
      consecutive += 1
      maximum = if rule.direction > 0 { maximum.max(value) } else { value }
    } else {
      consecutive = 0
    }
  }
  let triggered = consecutive >= rule.consecutive_windows
  {
    rule_name: rule.name,
    triggered,
    value: maximum,
    threshold: rule.threshold,
    consecutive,
    severity: if triggered {
      2
    } else if consecutive > 0 {
      1
    } else {
      0
    },
  }
}

///|
pub fn evaluate_availability_alert(
  window : TelemetryWindow,
  target : Double,
  minimum_samples : Int,
) -> AlertDecision {
  let rule = alert_rule(
    name="availability",
    threshold=target,
    direction=-1,
    minimum_samples~,
    consecutive_windows=1,
  )
  evaluate_alert(rule, [telemetry_window_availability(window)])
}

///|
pub fn evaluate_burn_rate_alert(
  window : TelemetryWindow,
  target : Double,
  threshold : Double,
) -> AlertDecision {
  let rule = alert_rule(
    name="error-budget-burn",
    threshold~,
    direction=1,
    minimum_samples=1,
    consecutive_windows=1,
  )
  evaluate_alert(rule, [telemetry_window_burn_rate(window, target)])
}

///|
pub fn alert_severity_score(decision : AlertDecision) -> Double {
  if decision.triggered {
    decision.severity.to_double() * decision.value.abs()
  } else {
    0.0
  }
}

///|
pub struct ForecastPoint {
  horizon : Int
  value : Double
  lower : Double
  upper : Double
}

///|
pub struct ForecastSeries {
  points : Array[ForecastPoint]
  slope : Double
  intercept : Double
  residual_scale : Double
}

///|
fn linear_intercept(values : Array[Double], slope : Double) -> Double {
  if values.is_empty() {
    0.0
  } else {
    values.fold(init=0.0, (total, value) => total + value) /
    values.length().to_double() -
    slope * (values.length() - 1).to_double() / 2.0
  }
}

///|
fn linear_slope(values : Array[Double]) -> Double {
  let n = values.length()
  if n < 2 {
    0.0
  } else {
    let mean_x = (n - 1).to_double() / 2.0
    let mean_y = values.fold(init=0.0, (total, value) => total + value) /
      n.to_double()
    let mut numerator = 0.0
    let mut denominator = 0.0
    for i in 0..<n {
      let x = i.to_double() - mean_x
      numerator += x * (values[i] - mean_y)
      denominator += x * x
    }
    if denominator == 0.0 {
      0.0
    } else {
      numerator / denominator
    }
  }
}

///|
pub fn forecast_linear(values : Array[Double], horizon : Int) -> ForecastSeries {
  if horizon < 1 {
    abort("forecast horizon must be positive")
  }
  let slope = linear_slope(values)
  let intercept = linear_intercept(values, slope)
  let residuals = Array::makei(values.length(), i => {
    values[i] - (intercept + slope * i.to_double())
  })
  let residual_scale = if residuals.is_empty() {
    0.0
  } else {
    (residuals.fold(init=0.0, (total, value) => total + value * value) /
    residuals.length().to_double()).sqrt()
  }
  let last_index = values.length().max(1)
  let points = Array::makei(horizon, i => {
    let value = intercept + slope * (last_index + i).to_double()
    let spread = residual_scale *
      (1.0 + i.to_double() / horizon.to_double()).sqrt()
    { horizon: i + 1, value, lower: value - spread, upper: value + spread }
  })
  { points, slope, intercept, residual_scale }
}

///|
pub fn forecast_values(forecast : ForecastSeries) -> Array[Double] {
  forecast.points.map(point => point.value)
}

///|
pub fn forecast_lower(forecast : ForecastSeries) -> Array[Double] {
  forecast.points.map(point => point.lower)
}

///|
pub fn forecast_upper(forecast : ForecastSeries) -> Array[Double] {
  forecast.points.map(point => point.upper)
}

///|
pub fn forecast_trend(forecast : ForecastSeries) -> String {
  if forecast.slope > 1.0e-12 {
    "increasing"
  } else if forecast.slope < -1.0e-12 {
    "decreasing"
  } else {
    "stable"
  }
}

///|
pub fn forecast_endpoint(forecast : ForecastSeries) -> Double {
  if forecast.points.is_empty() {
    forecast.intercept
  } else {
    forecast.points[forecast.points.length() - 1].value
  }
}

///|
pub fn forecast_risk_score(
  forecast : ForecastSeries,
  target : Double,
) -> Double {
  let endpoint = forecast_endpoint(forecast)
  if target == 0.0 {
    endpoint.abs()
  } else {
    (endpoint - target).abs() / target.abs()
  }
}

///|
pub struct HealthSnapshot {
  availability : Double
  stability : Double
  coverage : Double
  freshness : Double
  health_score : Double
  status : String
}

///|
pub fn health_snapshot(
  window : TelemetryWindow,
  target : Double,
) -> HealthSnapshot {
  if target < 0.0 || target > 1.0 {
    abort("target must be between zero and one")
  }
  let availability = telemetry_window_availability(window)
  let stability = 1.0 -
    telemetry_window_coefficient_of_variation(window).min(1.0)
  let coverage = telemetry_window_coverage(window)
  let freshness = if window.points.is_empty() { 0.0 } else { 1.0 }
  let target_factor = if target == 0.0 {
    availability
  } else {
    (availability / target).min(1.0)
  }
  let score = (0.45 * target_factor +
  0.25 * stability +
  0.20 * coverage +
  0.10 * freshness).min(1.0)
  let status = if score >= 0.90 {
    "healthy"
  } else if score >= 0.70 {
    "degraded"
  } else {
    "critical"
  }
  { availability, stability, coverage, freshness, health_score: score, status }
}

///|
pub fn health_score(snapshot : HealthSnapshot) -> Double {
  snapshot.health_score
}

///|
pub fn health_status(snapshot : HealthSnapshot) -> String {
  snapshot.status
}

///|
pub fn health_is_actionable(snapshot : HealthSnapshot) -> Bool {
  snapshot.status != "healthy"
}

///|
pub fn health_gap(snapshot : HealthSnapshot, target : Double) -> Double {
  (target - snapshot.availability).max(0.0)
}

///|
pub fn health_risk_index(snapshot : HealthSnapshot) -> Double {
  1.0 - snapshot.health_score
}

///|
pub struct ReliabilitySnapshot {
  time : Double
  reliability : Double
  hazard : Double
  cumulative_hazard : Double
  mission_success : Double
}

///|
pub fn reliability_snapshot(
  model : ReliabilityModel,
  time : Double,
  mission_count : Int,
) -> ReliabilitySnapshot {
  if time < 0.0 || mission_count < 1 {
    abort("invalid reliability snapshot")
  }
  let reliability = model.survival(time)
  let mission_success = @math.pow(reliability, mission_count.to_double())
  let hazard = model_hazard(model, time)
  {
    time,
    reliability,
    hazard,
    cumulative_hazard: -safe_log_probability(reliability),
    mission_success,
  }
}

///|
pub fn snapshot_margin(
  snapshot : ReliabilitySnapshot,
  target : Double,
) -> Double {
  snapshot.reliability - target
}

///|
pub fn snapshot_failure_probability(snapshot : ReliabilitySnapshot) -> Double {
  1.0 - snapshot.reliability
}

///|
pub fn snapshot_expected_failures(
  snapshot : ReliabilitySnapshot,
  population : Int,
) -> Double {
  if population < 0 {
    abort("population must be non-negative")
  }
  population.to_double() * snapshot_failure_probability(snapshot)
}

///|
pub fn snapshot_target_time(
  model : ReliabilityModel,
  target : Double,
) -> Double {
  if target <= 0.0 || target >= 1.0 {
    abort("target reliability must be between zero and one")
  }
  model_quantile(model, 1.0 - target)
}

///|
pub fn snapshot_series(
  model : ReliabilityModel,
  times : Array[Double],
  mission_count : Int,
) -> Array[ReliabilitySnapshot] {
  times.map(time => reliability_snapshot(model, time, mission_count))
}

///|
pub fn snapshot_checksum(snapshots : Array[ReliabilitySnapshot]) -> Double {
  snapshots.fold(init=0.0, (total, snapshot) => {
    total + snapshot.reliability + snapshot.hazard + snapshot.mission_success
  })
}

///|
pub fn rolling_windows(
  points : Array[TelemetryPoint],
  window_size : Int,
  step : Int,
) -> Array[TelemetryWindow] {
  if window_size < 1 || step < 1 {
    abort("window size and step must be positive")
  }
  if points.is_empty() {
    []
  } else {
    let count = if points.length() < window_size {
      1
    } else {
      (points.length() - window_size) / step + 1
    }
    Array::makei(count, i => {
      let offset = i * step
      let last = (offset + window_size - 1).min(points.length() - 1)
      let selected = Array::makei(last - offset + 1, j => points[offset + j])
      telemetry_window(
        selected,
        start=selected[0].timestamp,
        end=selected[selected.length() - 1].timestamp.max(
          selected[0].timestamp + 1.0,
        ),
        interval=1.0,
      )
    })
  }
}

///|
pub fn rolling_availability(
  points : Array[TelemetryPoint],
  window_size : Int,
  step : Int,
) -> Array[Double] {
  rolling_windows(points, window_size, step).map(window => {
    telemetry_window_availability(window)
  })
}

///|
pub fn rolling_failure_rates(
  points : Array[TelemetryPoint],
  window_size : Int,
  step : Int,
) -> Array[Double] {
  rolling_windows(points, window_size, step).map(window => {
    telemetry_window_failure_rate(window)
  })
}

///|
pub fn rolling_means(
  points : Array[TelemetryPoint],
  window_size : Int,
  step : Int,
) -> Array[Double] {
  rolling_windows(points, window_size, step).map(window => {
    telemetry_window_mean(window)
  })
}

///|
pub fn rolling_standard_deviations(
  points : Array[TelemetryPoint],
  window_size : Int,
  step : Int,
) -> Array[Double] {
  rolling_windows(points, window_size, step).map(window => {
    telemetry_window_standard_deviation(window)
  })
}

///|
pub fn rolling_burn_rates(
  points : Array[TelemetryPoint],
  window_size : Int,
  step : Int,
  target : Double,
) -> Array[Double] {
  rolling_windows(points, window_size, step).map(window => {
    telemetry_window_burn_rate(window, target)
  })
}

///|
pub fn rolling_health(
  points : Array[TelemetryPoint],
  window_size : Int,
  step : Int,
  target : Double,
) -> Array[Double] {
  rolling_windows(points, window_size, step).map(window => {
    health_score(health_snapshot(window, target))
  })
}

///|
pub fn change_points(values : Array[Double], threshold : Double) -> Array[Int] {
  if threshold < 0.0 {
    abort("threshold must be non-negative")
  }
  if values.length() < 2 {
    []
  } else {
    let result = []
    for i in 1..<values.length() {
      if (values[i] - values[i - 1]).abs() >= threshold {
        result.push(i)
      }
    }
    result
  }
}

///|
pub fn change_magnitudes(values : Array[Double]) -> Array[Double] {
  if values.length() < 2 {
    []
  } else {
    Array::makei(values.length() - 1, i => values[i + 1] - values[i])
  }
}

///|
pub fn change_direction(value : Double) -> Int {
  if value > 0.0 {
    1
  } else if value < 0.0 {
    -1
  } else {
    0
  }
}

///|
pub fn change_directions(values : Array[Double]) -> Array[Int] {
  change_magnitudes(values).map(value => change_direction(value))
}

///|
pub fn positive_change_fraction(values : Array[Double]) -> Double {
  let changes = change_magnitudes(values)
  if changes.is_empty() {
    0.0
  } else {
    changes
    .fold(init=0, (count, value) => if value > 0.0 { count + 1 } else { count })
    .to_double() /
    changes.length().to_double()
  }
}

///|
pub fn negative_change_fraction(values : Array[Double]) -> Double {
  let changes = change_magnitudes(values)
  if changes.is_empty() {
    0.0
  } else {
    changes
    .fold(init=0, (count, value) => if value < 0.0 { count + 1 } else { count })
    .to_double() /
    changes.length().to_double()
  }
}

///|
pub fn total_absolute_change(values : Array[Double]) -> Double {
  change_magnitudes(values).fold(init=0.0, (total, value) => total + value.abs())
}

///|
pub fn autocorrelation_lag(values : Array[Double], lag : Int) -> Double {
  if lag < 0 || lag >= values.length() {
    abort("invalid autocorrelation lag")
  }
  let count = values.length() - lag
  if count < 2 {
    0.0
  } else {
    let left = Array::makei(count, i => values[i])
    let right = Array::makei(count, i => values[i + lag])
    let left_mean = left.fold(init=0.0, (total, value) => total + value) /
      count.to_double()
    let right_mean = right.fold(init=0.0, (total, value) => total + value) /
      count.to_double()
    let mut numerator = 0.0
    let mut left_scale = 0.0
    let mut right_scale = 0.0
    for i in 0..<count {
      let left_delta = left[i] - left_mean
      let right_delta = right[i] - right_mean
      numerator += left_delta * right_delta
      left_scale += left_delta * left_delta
      right_scale += right_delta * right_delta
    }
    if left_scale == 0.0 || right_scale == 0.0 {
      0.0
    } else {
      numerator / (left_scale * right_scale).sqrt()
    }
  }
}

///|
pub fn rolling_autocorrelation(
  values : Array[Double],
  lag : Int,
  window : Int,
) -> Array[Double] {
  if window < lag + 2 {
    abort("window must exceed lag by at least two")
  }
  if values.length() < window {
    []
  } else {
    Array::makei(values.length() - window + 1, i => {
      let sample = Array::makei(window, j => values[i + j])
      autocorrelation_lag(sample, lag)
    })
  }
}

///|
pub fn observability_exponential_smoothing(
  values : Array[Double],
  alpha : Double,
) -> Array[Double] {
  if alpha <= 0.0 || alpha > 1.0 {
    abort("alpha must be in (0, 1]")
  }
  if values.is_empty() {
    []
  } else {
    let result = Array::make(values.length(), 0.0)
    result[0] = values[0]
    for i in 1..<values.length() {
      result[i] = alpha * values[i] + (1.0 - alpha) * result[i - 1]
    }
    result
  }
}

///|
pub fn double_exponential_smoothing(
  values : Array[Double],
  alpha : Double,
  beta : Double,
) -> Array[Double] {
  if alpha <= 0.0 || alpha > 1.0 || beta <= 0.0 || beta > 1.0 {
    abort("smoothing parameters must be in (0, 1]")
  }
  if values.is_empty() {
    []
  } else if values.length() == 1 {
    [values[0]]
  } else {
    let result = Array::make(values.length(), 0.0)
    let mut level = values[0]
    let mut trend = values[1] - values[0]
    result[0] = level
    for i in 1..<values.length() {
      let previous_level = level
      level = alpha * values[i] + (1.0 - alpha) * (level + trend)
      trend = beta * (level - previous_level) + (1.0 - beta) * trend
      result[i] = level + trend
    }
    result
  }
}

///|
pub fn smoothing_residuals(
  values : Array[Double],
  smoothed : Array[Double],
) -> Array[Double] {
  if values.length() != smoothed.length() {
    abort("series lengths must match")
  }
  Array::makei(values.length(), i => values[i] - smoothed[i])
}

///|
pub fn smoothing_rmse(
  values : Array[Double],
  smoothed : Array[Double],
) -> Double {
  let residuals = smoothing_residuals(values, smoothed)
  if residuals.is_empty() {
    0.0
  } else {
    (residuals.fold(init=0.0, (total, value) => total + value * value) /
    residuals.length().to_double()).sqrt()
  }
}

///|
pub fn smoothing_mae(
  values : Array[Double],
  smoothed : Array[Double],
) -> Double {
  let residuals = smoothing_residuals(values, smoothed)
  if residuals.is_empty() {
    0.0
  } else {
    residuals.fold(init=0.0, (total, value) => total + value.abs()) /
    residuals.length().to_double()
  }
}

///|
pub fn quantile_rank(values : Array[Double], value : Double) -> Double {
  if values.is_empty() {
    0.0
  } else {
    values
    .fold(init=0, (count, item) => if item <= value { count + 1 } else { count })
    .to_double() /
    values.length().to_double()
  }
}

///|
pub fn exceedance_probability(
  values : Array[Double],
  threshold : Double,
) -> Double {
  if values.is_empty() {
    0.0
  } else {
    values
    .fold(init=0, (count, value) => {
      if value > threshold {
        count + 1
      } else {
        count
      }
    })
    .to_double() /
    values.length().to_double()
  }
}

///|
pub fn empirical_tail_mean(
  values : Array[Double],
  threshold : Double,
) -> Double {
  let tail = values.filter(value => value > threshold)
  if tail.is_empty() {
    threshold
  } else {
    tail.fold(init=0.0, (total, value) => total + value) /
    tail.length().to_double()
  }
}

///|
pub fn conditional_exceedance_mean(
  values : Array[Double],
  threshold : Double,
) -> Double {
  empirical_tail_mean(values, threshold) - threshold
}

///|
pub fn percentile_exceedance(
  values : Array[Double],
  threshold : Double,
  percentile : Double,
) -> Double {
  if percentile < 0.0 || percentile > 1.0 {
    abort("percentile must be between zero and one")
  }
  let tail = values.filter(value => value > threshold)
  if tail.is_empty() {
    threshold
  } else {
    let average = tail.fold(init=0.0, (total, value) => total + value) /
      tail.length().to_double()
    threshold + (average - threshold) * percentile
  }
}

///|
pub struct CapacityPlan {
  baseline : Double
  peak : Double
  headroom : Double
  target : Double
  required_capacity : Double
  utilization : Double
  breach : Bool
}

///|
pub fn capacity_plan(
  observations : Array[Double],
  target_utilization : Double,
  safety_factor : Double,
) -> CapacityPlan {
  if target_utilization <= 0.0 ||
    target_utilization > 1.0 ||
    safety_factor < 0.0 {
    abort("invalid capacity planning parameters")
  }
  let baseline = if observations.is_empty() {
    0.0
  } else {
    observations.fold(init=0.0, (total, value) => total + value) /
    observations.length().to_double()
  }
  let peak = if observations.is_empty() {
    0.0
  } else {
    observations.fold(init=0.0, (maximum, value) => maximum.max(value))
  }
  let target = peak * (1.0 + safety_factor)
  let required_capacity = if target_utilization == 0.0 {
    target
  } else {
    target / target_utilization
  }
  let utilization = if required_capacity == 0.0 {
    0.0
  } else {
    peak / required_capacity
  }
  {
    baseline,
    peak,
    headroom: required_capacity - peak,
    target,
    required_capacity,
    utilization,
    breach: utilization > target_utilization,
  }
}

///|
pub fn capacity_headroom(plan : CapacityPlan) -> Double {
  plan.headroom
}

///|
pub fn capacity_risk(plan : CapacityPlan) -> Double {
  if plan.required_capacity == 0.0 {
    0.0
  } else {
    (plan.peak / plan.required_capacity).min(1.0)
  }
}

///|
pub fn capacity_scale_factor(plan : CapacityPlan) -> Double {
  if plan.baseline <= 0.0 {
    1.0
  } else {
    plan.required_capacity / plan.baseline
  }
}

///|
pub fn capacity_breach(plan : CapacityPlan) -> Bool {
  plan.breach
}

///|
pub fn capacity_forecast(
  observations : Array[Double],
  horizon : Int,
  target_utilization : Double,
  safety_factor : Double,
) -> Array[Double] {
  let forecast = forecast_linear(observations, horizon)
  let plan = capacity_plan(observations, target_utilization, safety_factor)
  forecast_values(forecast).map(value => value.max(plan.required_capacity))
}

///|
pub struct ReliabilityBudget {
  target : Double
  observed : Double
  remaining : Double
  burn_rate : Double
  consumed_fraction : Double
  status : String
}

///|
pub fn reliability_budget(
  window : TelemetryWindow,
  target : Double,
) -> ReliabilityBudget {
  if target < 0.0 || target >= 1.0 {
    abort("target must be in [0, 1)")
  }
  let observed = telemetry_window_availability(window)
  let remaining = telemetry_window_error_budget(window, target)
  let budget = (1.0 - target) * telemetry_window_duration(window)
  let consumed = if budget == 0.0 {
    0.0
  } else {
    (1.0 - observed) * telemetry_window_duration(window) / budget
  }
  let burn = telemetry_window_burn_rate(window, target)
  let status = if burn > 2.0 {
    "exhausted"
  } else if burn > 1.0 {
    "burning"
  } else {
    "safe"
  }
  {
    target,
    observed,
    remaining,
    burn_rate: burn,
    consumed_fraction: consumed,
    status,
  }
}

///|
pub fn budget_is_exhausted(budget : ReliabilityBudget) -> Bool {
  budget.status == "exhausted"
}

///|
pub fn budget_remaining(budget : ReliabilityBudget) -> Double {
  budget.remaining
}

///|
pub fn budget_consumed(budget : ReliabilityBudget) -> Double {
  budget.consumed_fraction
}

///|
pub fn budget_burn_rate(budget : ReliabilityBudget) -> Double {
  budget.burn_rate
}

///|
pub fn budget_status(budget : ReliabilityBudget) -> String {
  budget.status
}

///|
pub fn budget_projection(
  budget : ReliabilityBudget,
  future_windows : Int,
) -> Double {
  if future_windows < 0 {
    abort("future window count must be non-negative")
  }
  budget.remaining - budget.burn_rate * future_windows.to_double()
}

///|
pub fn budget_recovery_needed(budget : ReliabilityBudget) -> Double {
  (budget.observed - budget.target).max(0.0)
}

///|
pub fn incident_burden(
  incidents : Array[IncidentRecord],
  window : Double,
) -> Double {
  if window <= 0.0 {
    abort("window must be positive")
  }
  incident_severity_weight(incidents) / window
}

///|
pub fn weighted_reliability_score(
  availability : Double,
  stability : Double,
  incident_burden_value : Double,
  target : Double,
) -> Double {
  if availability < 0.0 ||
    availability > 1.0 ||
    stability < 0.0 ||
    stability > 1.0 ||
    target <= 0.0 ||
    target > 1.0 {
    abort("invalid reliability score inputs")
  }
  let target_score = (availability / target).min(1.0)
  let burden_score = (1.0 - incident_burden_value).max(0.0).min(1.0)
  (0.55 * target_score + 0.30 * stability + 0.15 * burden_score).min(1.0)
}

///|
pub fn score_label(score : Double) -> String {
  if score >= 0.90 {
    "excellent"
  } else if score >= 0.75 {
    "good"
  } else if score >= 0.50 {
    "watch"
  } else {
    "poor"
  }
}

///|
pub fn score_gap(score : Double, target : Double) -> Double {
  (target - score).max(0.0)
}

///|
pub fn score_to_percent(score : Double) -> Double {
  score.max(0.0).min(1.0) * 100.0
}

///|
pub fn score_is_passing(score : Double, target : Double) -> Bool {
  score >= target
}

///|
pub fn score_checksum(scores : Array[Double]) -> Double {
  scores.fold(init=0.0, (total, score) => total + score)
}
