///|
test "end to end reliability workflow" {
  let records = simulate_weibull_records(2026, 100.0, 1.6, 200, 150.0)
  let quality = inspect_times(records.map(record => record.time))
  inspect(quality.invalid_count, content="0")
  let curve = kaplan_meier(records)
  let fit = weibull_fit_censored(records)
  let model = model_from_fit(fit)
  let comparison = compare_fits([fit, exponential_fit_censored(records)])
  let metric = model_metric(model, 50.0, 0.95)
  inspect(curve.points().length() > 0, content="true")
  inspect(fit.parameters[0] > 0.0, content="true")
  inspect(comparison.names.length(), content="2")
  inspect(metric.lower >= 0.0 && metric.upper <= 1.0, content="true")
}

///|
test "mission and service planning" {
  let first = ReliabilityModel::ExponentialModel(Exponential::new(0.01))
  let second = ReliabilityModel::WeibullModel(Weibull::new(100.0, 2.0))
  inspect(
    mission_success_probability([first, second], 10.0) > 0.8,
    content="true",
  )
  inspect(service_capacity(2.0, 0.25, 0.8) >= 1, content="true")
  inspect(
    downtime_budget_from_availability(720.0, 0.99) > 7.19 &&
    downtime_budget_from_availability(720.0, 0.99) < 7.21,
    content="true",
  )
}

///|
test "safety and SLA boundaries" {
  let risk = risk_item(
    name="bearing",
    severity=8,
    occurrence=5,
    detection=6,
    recommended_action="inspect lubrication",
  )
  inspect(risk.risk_priority_number, content="240")
  inspect(risk_level(risk.risk_priority_number), content="medium")
  inspect(safety_integrity_level(1.0e-4), content="SIL3")
  inspect(alert_severity(14.0), content="critical")
}
