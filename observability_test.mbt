///|
test "telemetry window metrics" {
  let points = [
    telemetry_point(timestamp=0.0, value=10.0, healthy=true, weight=1.0),
    telemetry_point(timestamp=1.0, value=12.0, healthy=true, weight=1.0),
    telemetry_point(timestamp=2.0, value=8.0, healthy=false, weight=2.0),
  ]
  let window = telemetry_window(points, start=0.0, end=2.0, interval=1.0)
  inspect(telemetry_window_count(window), content="3")
  inspect(telemetry_window_healthy_count(window), content="2")
  inspect(telemetry_window_unhealthy_count(window), content="1")
  inspect(
    telemetry_window_mean(window) > 9.49 && telemetry_window_mean(window) < 9.51,
    content="true",
  )
  inspect(
    telemetry_window_availability(window) > 0.49 &&
    telemetry_window_availability(window) < 0.51,
    content="true",
  )
  inspect(telemetry_window_event_count(window), content="1")
}

///|
test "telemetry thresholds and gaps" {
  let points = [
    telemetry_point(timestamp=0.0, value=1.0, healthy=true, weight=1.0),
    telemetry_point(timestamp=2.0, value=5.0, healthy=true, weight=1.0),
    telemetry_point(timestamp=5.0, value=9.0, healthy=true, weight=1.0),
  ]
  let window = telemetry_window(points, start=0.0, end=6.0, interval=1.0)
  inspect(telemetry_window_threshold_count(window, 2.0, 8.0), content="2")
  inspect(telemetry_window_above(window, 4.0), content="2")
  inspect(telemetry_window_below(window, 2.0), content="1")
  inspect(telemetry_window_gap(window), content="3")
  inspect(telemetry_window_coverage(window) > 0.83, content="true")
}

///|
test "incident union is order independent" {
  let incidents = [
    incident_record(start=5.0, end=8.0, severity=1, cause=2),
    incident_record(start=1.0, end=4.0, severity=2, cause=1),
    incident_record(start=3.0, end=6.0, severity=1, cause=1),
  ]
  inspect(incident_union_duration(incidents), content="7")
  inspect(incident_total_duration(incidents), content="9")
  inspect(incident_count_by_cause(incidents, 1), content="2")
  inspect(incident_count_by_severity(incidents, 1), content="2")
}

///|
test "alert rules and reliability budget" {
  let points = [
    telemetry_point(timestamp=0.0, value=0.0, healthy=false, weight=1.0),
    telemetry_point(timestamp=1.0, value=0.0, healthy=true, weight=1.0),
  ]
  let window = telemetry_window(points, start=0.0, end=2.0, interval=1.0)
  let alert = evaluate_availability_alert(window, 0.99, 1)
  inspect(alert.triggered, content="true")
  let budget = reliability_budget(window, 0.99)
  inspect(budget_is_exhausted(budget), content="true")
  inspect(budget_burn_rate(budget) > 10.0, content="true")
}

///|
test "forecast and smoothing" {
  let values = [1.0, 2.0, 3.0, 4.0]
  let forecast = forecast_linear(values, 2)
  inspect(forecast_trend(forecast), content="increasing")
  inspect(forecast_endpoint(forecast) > 5.9, content="true")
  let smoothed = observability_exponential_smoothing(values, 0.5)
  inspect(smoothed.length(), content="4")
  inspect(smoothed[3] > 3.0, content="true")
  inspect(smoothing_mae(values, smoothed) >= 0.0, content="true")
}

///|
test "rolling and change diagnostics" {
  let points = Array::makei(8, i => {
    telemetry_point(
      timestamp=i.to_double(),
      value=i.to_double(),
      healthy=true,
      weight=1.0,
    )
  })
  inspect(rolling_means(points, 4, 2).length(), content="3")
  inspect(change_points([1.0, 1.1, 3.0, 3.1], 1.0).length(), content="1")
  inspect(positive_change_fraction([1.0, 2.0, 3.0]), content="1")
  inspect(total_absolute_change([1.0, 3.0, 2.0]), content="3")
  inspect(autocorrelation_lag([1.0, 2.0, 3.0, 4.0], 1) > 0.9, content="true")
}

///|
test "capacity and model snapshots" {
  let plan = capacity_plan([10.0, 12.0, 14.0], 0.8, 0.1)
  inspect(capacity_breach(plan), content="false")
  inspect(capacity_headroom(plan) > 3.0, content="true")
  let model = ReliabilityModel::WeibullModel(Weibull::new(100.0, 2.0))
  let snapshot = reliability_snapshot(model, 10.0, 2)
  inspect(snapshot.reliability > 0.98, content="true")
  inspect(snapshot_failure_probability(snapshot) < 0.02, content="true")
  inspect(snapshot_expected_failures(snapshot, 100) > 0.0, content="true")
}

///|
test "health score boundaries" {
  let point = telemetry_point(
    timestamp=0.0,
    value=1.0,
    healthy=true,
    weight=1.0,
  )
  let window = telemetry_window([point], start=0.0, end=1.0, interval=1.0)
  let snapshot = health_snapshot(window, 0.99)
  inspect(
    health_score(snapshot) >= 0.0 && health_score(snapshot) <= 1.0,
    content="true",
  )
  inspect(health_status(snapshot), content="degraded")
  inspect(score_to_percent(health_risk_index(snapshot)) >= 0.0, content="true")
}
