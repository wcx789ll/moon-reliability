///|
test "reporting output contains schema" {
  let curve = kaplan_meier([failure(1.0), failure(2.0), right_censored(3.0)])
  let csv = survival_curve_csv(curve)
  inspect(csv.contains("time,at_risk"), content="true")
  let fit = exponential_fit_censored([failure(1.0), failure(2.0)])
  inspect(format_fit(fit).contains("exponential"), content="true")
}

///|
test "reliability score and report" {
  let model = ReliabilityModel::ExponentialModel(Exponential::new(0.01))
  let score = build_scorecard(model, 0.999, 0.01, 0.99, 10.0)
  inspect(scorecard_risk_flag(score, 0.5), content="false")
  inspect(recommendation_count(score) >= 0, content="true")
  inspect(
    observation_summary_markdown(summarize([failure(1.0), right_censored(2.0)])).contains(
      "count",
    ),
    content="true",
  )
}

///|
test "benchmark kernels checksum" {
  let grid = benchmark_grid(10)
  let model = ReliabilityModel::WeibullModel(Weibull::new(100.0, 2.0))
  let checksum = benchmark_distribution_kernel(model, grid, 2)
  inspect(checksum > 0.0, content="true")
  let result = benchmark_result_from_measurement("unit", 10, 1000L, checksum)
  inspect(result.operations_per_second, content="10000")
}
