///|
test "exponential censored mle" {
  let records = [
    failure(1.0),
    failure(2.0),
    right_censored(4.0),
    right_censored(5.0),
  ]
  let fit = exponential_fit_censored(records)
  inspect(fit.parameters[0] > 0.1 && fit.parameters[0] < 0.25, content="true")
  inspect(fit.iterations == 1, content="true")
  inspect(fit.aic < fit.bic, content="true")
}

///|
test "weibull censored fit returns positive parameters" {
  let records = [
    failure(2.0),
    failure(3.0),
    failure(5.0),
    right_censored(7.0),
    right_censored(8.0),
  ]
  let fit = weibull_fit_censored(records)
  inspect(fit.parameters[0] > 0.0, content="true")
  inspect(fit.parameters[1] > 0.0, content="true")
  inspect(fit.standard_errors.length(), content="2")
}

///|
test "lognormal censored fit" {
  let records = [failure(2.0), failure(3.0), failure(4.0), right_censored(6.0)]
  let fit = lognormal_fit_censored(records)
  inspect(fit.parameters[1] > 0.0, content="true")
  inspect(fit.distribution, content="lognormal-censored")
}

///|
test "model likelihood conventions" {
  let model = ReliabilityModel::ExponentialModel(Exponential::new(0.5))
  let failed = model.log_likelihood([failure(2.0)])
  let censored = model.log_likelihood([right_censored(2.0)])
  inspect(failed < 0.0, content="true")
  inspect(censored < 0.0, content="true")
}

///|
test "fit selection" {
  let data = [1.0, 2.0, 3.0, 4.0, 5.0]
  let comparison = compare_fits([normal_fit(data), gamma_fit(data)])
  inspect(akaike_weights(comparison).length(), content="2")
  inspect(comparison.preferred_aic >= 0, content="true")
}

///|
test "model metrics" {
  let model = ReliabilityModel::WeibullModel(Weibull::new(100.0, 2.0))
  inspect(model_mean(model) > 88.0 && model_mean(model) < 89.0, content="true")
  inspect(
    model_quantile(model, 0.5) > 83.0 && model_quantile(model, 0.5) < 84.0,
    content="true",
  )
  inspect(model_hazard(model, 10.0) > 0.0, content="true")
}
