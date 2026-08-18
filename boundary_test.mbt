///|
test "boundary probabilities and negative time conventions" {
  let exponential = Exponential::new(0.2)
  inspect(exponential.cdf(-1.0), content="0")
  inspect(exponential.reliability(-1.0), content="1")
  inspect(exponential.quantile(0.0), content="0")
  let weibull = Weibull::new(10.0, 2.0)
  inspect(weibull.cdf(-2.0), content="0")
  inspect(weibull.reliability(-2.0), content="1")
}

///|
test "normal distribution symmetry" {
  let model = Normal::new(5.0, 2.0)
  inspect(model.cdf(5.0) > 0.499 && model.cdf(5.0) < 0.501, content="true")
  inspect(model.pdf(3.0) == model.pdf(7.0), content="true")
  inspect(
    model.quantile(0.5) > 4.99 && model.quantile(0.5) < 5.01,
    content="true",
  )
}

///|
test "gamma cdf and quantile round trip" {
  let model = GammaDistribution::new(2.0, 0.5)
  let q = model.quantile(0.75)
  inspect(model.cdf(q) > 0.749 && model.cdf(q) < 0.751, content="true")
  inspect(model.mean(), content="4")
  inspect(model.variance(), content="8")
}

///|
test "log logistic moments" {
  let model = LogLogistic::new(10.0, 3.0)
  inspect(model.cdf(0.0), content="0")
  inspect(
    model.reliability(10.0) > 0.49 && model.reliability(10.0) < 0.51,
    content="true",
  )
  inspect(model.quantile(0.5), content="10")
}

///|
test "observation validation" {
  let good = failure(10.0).with_metadata(cause=2, weight=3.0)
  debug_inspect(validate_observation(good), content="None")
  inspect(
    validate_dataset([failure(1.0), right_censored(2.0)]).length(),
    content="0",
  )
  inspect(validate_dataset([failure(-1.0)]).length(), content="1")
}

///|
test "weighted summary" {
  inspect(weighted_mean([1.0, 3.0], [1.0, 1.0]), content="2")
  inspect(
    weighted_quantile([1.0, 2.0, 10.0], [1.0, 1.0, 1.0], 0.5),
    content="2",
  )
  inspect(
    median_absolute_deviation([1.0, 2.0, 3.0, 4.0, 100.0]) >= 1.0,
    content="true",
  )
}

///|
test "numerical linear solver" {
  let solution = solve_linear_system([[2.0, 1.0], [1.0, 3.0]], [5.0, 6.0])
  inspect(solution[0] > 1.79 && solution[0] < 1.81, content="true")
  inspect(solution[1] > 1.39 && solution[1] < 1.41, content="true")
}

///|
test "safe probability clamps" {
  inspect(clamp_probability(-0.1), content="0")
  inspect(clamp_probability(1.1), content="1")
  inspect(safe_log_probability(0.0) < -600.0, content="true")
}
