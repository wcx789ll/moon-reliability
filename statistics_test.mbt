///|
test "descriptive statistics" {
  let values = [1.0, 2.0, 3.0, 4.0, 5.0]
  inspect(mean(values), content="3")
  inspect(variance(values), content="2.5")
  inspect(skewness(values) > -0.01 && skewness(values) < 0.01, content="true")
  inspect(quantile(values, 0.5), content="3")
  debug_inspect(rank_values([3.0, 1.0, 2.0]), content="[3, 1, 2]")
}

///|
test "robust and rolling statistics" {
  inspect(trimmed_mean([1.0, 2.0, 3.0, 4.0, 100.0], 0.2), content="3")
  debug_inspect(
    moving_average([1.0, 2.0, 3.0, 4.0], 2),
    content="[1.5, 2.5, 3.5]",
  )
  debug_inspect(first_difference([1.0, 3.0, 6.0]), content="[2, 3]")
  debug_inspect(seasonal_difference([1.0, 2.0, 4.0, 8.0], 2), content="[3, 6]")
}

///|
test "regression" {
  let fit = linear_regression([1.0, 2.0, 3.0, 4.0], [2.0, 4.0, 6.0, 8.0])
  inspect(fit.coefficients[0].abs() < 0.01, content="true")
  inspect(
    fit.coefficients[1] > 1.99 && fit.coefficients[1] < 2.01,
    content="true",
  )
  inspect(fit.r_squared > 0.999, content="true")
  inspect(predict_regression(fit, 5.0) > 9.99, content="true")
}

///|
test "change point and forecast" {
  let values = [1.0, 1.1, 0.9, 1.0, 5.0, 5.1, 4.9, 5.0]
  debug_inspect(detect_level_shift(values, 2), content="Some(4)")
  let forecast = simple_forecast(values, 3, 0.4, 1.0)
  inspect(forecast.points.length(), content="3")
  inspect(forecast.residual_scale >= 0.0, content="true")
}

///|
test "data preparation" {
  let report = inspect_times([-1.0, 0.0, 1.0, 1.0])
  inspect(report.invalid_count, content="1")
  inspect(report.duplicate_count, content="1")
  debug_inspect(winsorize([1.0, 2.0, 100.0], 0.0, 0.5), content="[1, 2, 2]")
}
