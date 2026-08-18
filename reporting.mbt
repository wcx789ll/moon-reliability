///|
/// Human-readable compact reporting helpers; no I/O is required.
pub fn format_double(value : Double, digits : Int) -> String {
  let scale = @math.pow(10.0, digits.to_double())
  let rounded = @math.round(value * scale) / scale
  "\{rounded}"
}

///|
pub fn format_metric(metric : MetricEstimate) -> String {
  "estimate=\{format_double(metric.estimate, 6)}, 95%=[\{format_double(metric.lower, 6)}, \{format_double(metric.upper, 6)}]"
}

///|
pub fn format_fit(fit : FitResult) -> String {
  let parameters = fit.parameters
    .map(value => format_double(value, 6))
    .join(", ")
  "\{fit.distribution}: parameters=[\{parameters}], log_likelihood=\{format_double(fit.log_likelihood, 4)}, AIC=\{format_double(fit.aic, 4)}, BIC=\{format_double(fit.bic, 4)}"
}

///|
pub fn survival_curve_csv(curve : SurvivalCurve) -> String {
  let builder = StringBuilder::new()
  builder.write_string(
    "time,at_risk,events,censored,survival,standard_error,cumulative_hazard\n",
  )
  for point in curve.points {
    builder.write_string(
      "\{point.time},\{point.at_risk},\{point.events},\{point.censored},\{point.survival},\{point.standard_error},\{point.cumulative_hazard}\n",
    )
  }
  builder.to_string()
}

///|
pub fn life_table_csv(table : LifeTable) -> String {
  let builder = StringBuilder::new()
  builder.write_string(
    "lower,upper,exposed,failures,withdrawals,failure_probability,survival_probability,hazard\n",
  )
  for interval in table.intervals {
    builder.write_string(
      "\{interval.lower},\{interval.upper},\{interval.exposed},\{interval.failures},\{interval.withdrawals},\{interval.failure_probability},\{interval.survival_probability},\{interval.hazard}\n",
    )
  }
  builder.to_string()
}

///|
pub fn regression_markdown(model : RegressionResult) -> String {
  let builder = StringBuilder::new()
  builder.write_string("| metric | value |\n|---|---:|\n")
  builder.write_string("| observations | \{model.observations} |\n")
  builder.write_string("| R² | \{format_double(model.r_squared, 6)} |\n")
  builder.write_string(
    "| adjusted R² | \{format_double(model.adjusted_r_squared, 6)} |\n",
  )
  builder.write_string(
    "| residual sum of squares | \{format_double(model.residual_sum_squares, 6)} |\n",
  )
  builder.to_string()
}

///|
pub fn benchmark_markdown(results : Array[BenchmarkResult]) -> String {
  let builder = StringBuilder::new()
  builder.write_string(
    "| benchmark | iterations | elapsed (µs) | operations/s | checksum |\n|---|---:|---:|---:|---:|\n",
  )
  for result in results {
    builder.write_string(
      "| \{result.name} | \{result.iterations} | \{result.elapsed_micros} | \{format_double(result.operations_per_second, 2)} | \{format_double(result.checksum, 6)} |\n",
    )
  }
  builder.to_string()
}

///|
pub fn fit_report(fits : Array[FitResult]) -> String {
  let builder = StringBuilder::new()
  builder.write_string("# Reliability fit report\n\n")
  for fit in fits {
    builder.write_string("- \{format_fit(fit)}\n")
  }
  builder.to_string()
}

///|
pub fn observation_summary_markdown(summary : SampleSummary) -> String {
  "| count | failures | censored | mean | median | sd |\n|---:|---:|---:|---:|---:|---:|\n| \{summary.count} | \{summary.failures} | \{summary.censored} | \{format_double(summary.mean, 4)} | \{format_double(summary.median, 4)} | \{format_double(summary.standard_deviation, 4)} |"
}
