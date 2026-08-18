///|
test "reproducible random state" {
  let first = sample_exponential(42, 0.1, 5)
  let second = sample_exponential(42, 0.1, 5)
  inspect(
    first.length() == second.length() && first[0] == second[0],
    content="true",
  )
  inspect(first.all(value => value > 0.0), content="true")
}

///|
test "simulated censoring" {
  let records = simulate_weibull_records(7, 10.0, 2.0, 50, 12.0)
  inspect(records.length(), content="50")
  inspect(records.any(record => record.is_censored()), content="true")
  inspect(records.any(record => record.is_failure()), content="true")
}

///|
test "monte carlo interval" {
  let model = ReliabilityModel::ExponentialModel(Exponential::new(0.1))
  let result = monte_carlo_reliability(123, model, 10.0, 1000)
  inspect(result.estimate >= 0.0 && result.estimate <= 1.0, content="true")
  inspect(result.lower >= 0.0, content="true")
  inspect(result.upper <= 1.0, content="true")
}

///|
test "bootstrap mean" {
  let result = bootstrap_mean([1.0, 2.0, 3.0, 4.0], 100, 9, 0.95)
  inspect(result.estimate, content="2.5")
  inspect(result.standard_error > 0.0, content="true")
  inspect(
    result.lower <= result.estimate && result.upper >= result.estimate,
    content="true",
  )
}

///|
test "uncertainty propagation" {
  let result = delta_method(2.0, 0.1, x => x * x)
  inspect(result.estimate, content="4")
  inspect(result.lower < 4.0 && result.upper > 4.0, content="true")
  inspect(combine_estimates([1.0, 3.0], [1.0, 1.0]).estimate, content="2")
}
