///|
test "accelerated life models" {
  let temperature = [300.0, 320.0, 340.0, 360.0]
  let life = [100.0, 80.0, 65.0, 52.0]
  let model = fit_arrhenius(temperature, life, 300.0)
  inspect(model.predict_life(300.0) > 90.0, content="true")
  inspect(model.acceleration_factor(360.0) > 1.0, content="true")
  inspect(arrhenius_acceleration(0.7, 360.0, 300.0) < 1.0, content="true")
}

///|
test "system reliability" {
  inspect(
    series_reliability([0.9, 0.8]) > 0.719 &&
    series_reliability([0.9, 0.8]) < 0.721,
    content="true",
  )
  inspect(parallel_reliability([0.9, 0.8]) > 0.97, content="true")
  inspect(k_out_of_n_reliability(2, 0.9, 2), content="0.81")
  let system = build_reliability_system("pump", Series, [0.9, 0.8])
  inspect(
    system.reliability > 0.719 && system.reliability < 0.721,
    content="true",
  )
}

///|
test "maintenance optimization" {
  let model = ReliabilityModel::ExponentialModel(Exponential::new(0.01))
  let schedule = age_replacement_schedule(model, 5.0, 20.0, 10.0, 100.0, 10)
  inspect(schedule.ages.length(), content="10")
  inspect(schedule.selected_age >= 10.0, content="true")
  inspect(inspection_interval(model, 0.8, 1.0, 10.0) > 0.0, content="true")
}

///|
test "fleet spare planning" {
  let model = ReliabilityModel::ExponentialModel(Exponential::new(0.01))
  let plan = plan_fleet(model, 100, 10.0, 0.05, 2.0)
  inspect(plan.fleet_size, content="100")
  inspect(plan.spare_units >= 0, content="true")
  inspect(plan.stockout_probability <= 0.05, content="true")
}

///|
test "quality control flags" {
  let limits = control_limits(center=1.0, upper=3.0, lower=0.0, sigma=1.0, violations=[])
  inspect(run_rules([1.0, 10.0], limits).length() >= 1, content="true")
  inspect(capability_indices([1.0, 1.0, 1.0], 0.0, 2.0).0 > 0.0, content="true")
  inspect(
    defect_rate(1, 100).estimate > 0.009 && defect_rate(1, 100).estimate < 0.011,
    content="true",
  )
}

///|
test "sla and scorecard" {
  let policy = sla_policy(
    window=30.0,
    promised_availability=0.99,
    credit_rate=100.0,
    maximum_credit=50.0,
  )
  let result = evaluate_sla([0.1, 0.2], policy, 30.0)
  inspect(result.observed_availability > 0.98, content="true")
  let model = ReliabilityModel::ExponentialModel(Exponential::new(0.001))
  let score = build_scorecard(model, 0.999, 0.01, 0.95, 10.0)
  inspect(score.grade is "A" || score.grade is "B", content="true")
}
