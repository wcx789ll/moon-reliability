///|
/// Measurement kind used by a reliability data catalog.
pub(all) enum ReliabilityDataKind {
  ReliabilityContinuous
  ReliabilityCount
  ReliabilityTimestamp
  ReliabilityCategory
  ReliabilityBoolean
} derive(Debug, Eq)

///|
/// Column-level quality statistics computed before model fitting.
pub struct ReliabilityDataColumn {
  name : String
  kind : ReliabilityDataKind
  row_count : Int
  missing_count : Int
  invalid_count : Int
  duplicate_count : Int
  minimum : Double
  maximum : Double
  mean : Double
  standard_deviation : Double
  monotonic_violations : Int
}

///|
pub fn reliability_data_column(
  name : String,
  kind : ReliabilityDataKind,
  row_count : Int,
  missing_count : Int,
  invalid_count : Int,
  duplicate_count : Int,
  minimum : Double,
  maximum : Double,
  mean : Double,
  standard_deviation : Double,
  monotonic_violations : Int,
) -> ReliabilityDataColumn {
  if row_count < 0 ||
    missing_count < 0 ||
    invalid_count < 0 ||
    duplicate_count < 0 ||
    monotonic_violations < 0 ||
    standard_deviation < 0.0 {
    abort("invalid reliability data column")
  }
  {
    name,
    kind,
    row_count,
    missing_count,
    invalid_count,
    duplicate_count,
    minimum,
    maximum,
    mean,
    standard_deviation,
    monotonic_violations,
  }
}

///|
pub fn reliability_data_column_name(column : ReliabilityDataColumn) -> String {
  column.name
}

///|
pub fn reliability_data_column_missing_rate(
  column : ReliabilityDataColumn,
) -> Double {
  if column.row_count == 0 {
    0.0
  } else {
    column.missing_count.to_double() / column.row_count.to_double()
  }
}

///|
pub fn reliability_data_column_invalid_rate(
  column : ReliabilityDataColumn,
) -> Double {
  if column.row_count == 0 {
    0.0
  } else {
    column.invalid_count.to_double() / column.row_count.to_double()
  }
}

///|
pub fn reliability_data_column_duplicate_rate(
  column : ReliabilityDataColumn,
) -> Double {
  if column.row_count == 0 {
    0.0
  } else {
    column.duplicate_count.to_double() / column.row_count.to_double()
  }
}

///|
pub fn reliability_data_column_valid_count(
  column : ReliabilityDataColumn,
) -> Int {
  (column.row_count - column.missing_count - column.invalid_count).max(0)
}

///|
pub fn reliability_data_column_quality(
  column : ReliabilityDataColumn,
) -> Double {
  let missing = reliability_data_column_missing_rate(column).min(1.0)
  let invalid = reliability_data_column_invalid_rate(column).min(1.0)
  let duplicate = reliability_data_column_duplicate_rate(column).min(1.0)
  let order = if column.row_count == 0 {
    1.0
  } else {
    1.0 -
    (column.monotonic_violations.to_double() / column.row_count.to_double()).min(
      1.0,
    )
  }
  ((1.0 - missing) * (1.0 - invalid) * (1.0 - duplicate) * order)
  .max(0.0)
  .min(1.0)
}

///|
pub fn reliability_data_column_range(column : ReliabilityDataColumn) -> Double {
  (column.maximum - column.minimum).max(0.0)
}

///|
pub fn reliability_data_column_coefficient_of_variation(
  column : ReliabilityDataColumn,
) -> Double {
  if column.mean == 0.0 {
    0.0
  } else {
    column.standard_deviation / column.mean.abs()
  }
}

///|
pub fn reliability_data_column_is_usable(
  column : ReliabilityDataColumn,
  minimum_quality : Double,
) -> Bool {
  reliability_data_column_quality(column) >= minimum_quality &&
  reliability_data_column_valid_count(column) > 0
}

///|
/// A time-aligned observation row used for joining telemetry and event logs.
pub struct ReliabilityDataRow {
  timestamp : Double
  asset_id : Int
  value : Double
  event_code : Int
  is_failure : Bool
  is_censored : Bool
  source_quality : Double
}

///|
pub fn reliability_data_row(
  timestamp : Double,
  asset_id : Int,
  value : Double,
  event_code : Int,
  is_failure : Bool,
  is_censored : Bool,
  source_quality : Double,
) -> ReliabilityDataRow {
  if timestamp < 0.0 ||
    asset_id < 0 ||
    event_code < 0 ||
    source_quality < 0.0 ||
    source_quality > 1.0 ||
    (is_failure && is_censored) {
    abort("invalid reliability data row")
  }
  {
    timestamp,
    asset_id,
    value,
    event_code,
    is_failure,
    is_censored,
    source_quality,
  }
}

///|
pub fn reliability_data_row_is_observed(row : ReliabilityDataRow) -> Bool {
  !row.is_censored
}

///|
pub fn reliability_data_row_weight(row : ReliabilityDataRow) -> Double {
  row.source_quality.max(0.0).min(1.0)
}

///|
pub fn reliability_data_row_age(
  row : ReliabilityDataRow,
  commissioned_at : Double,
) -> Double {
  (row.timestamp - commissioned_at).max(0.0)
}

///|
pub fn reliability_data_row_adjusted_value(
  row : ReliabilityDataRow,
  baseline : Double,
  scale : Double,
) -> Double {
  if scale == 0.0 {
    row.value - baseline
  } else {
    (row.value - baseline) / scale
  }
}

///|
/// Dataset quality summary with deterministic provenance fields.
pub struct ReliabilityDataSet {
  dataset_id : String
  version : String
  rows : Array[ReliabilityDataRow]
  columns : Array[ReliabilityDataColumn]
  start_time : Double
  end_time : Double
  source_count : Int
}

///|
pub fn reliability_data_set(
  dataset_id : String,
  version : String,
  rows : Array[ReliabilityDataRow],
  columns : Array[ReliabilityDataColumn],
  start_time : Double,
  end_time : Double,
  source_count : Int,
) -> ReliabilityDataSet {
  if end_time < start_time || source_count < 0 {
    abort("invalid reliability data set")
  }
  { dataset_id, version, rows, columns, start_time, end_time, source_count }
}

///|
pub fn reliability_data_set_row_count(dataset : ReliabilityDataSet) -> Int {
  dataset.rows.length()
}

///|
pub fn reliability_data_set_column_count(dataset : ReliabilityDataSet) -> Int {
  dataset.columns.length()
}

///|
pub fn reliability_data_set_duration(dataset : ReliabilityDataSet) -> Double {
  dataset.end_time - dataset.start_time
}

///|
pub fn reliability_data_set_failure_count(dataset : ReliabilityDataSet) -> Int {
  dataset.rows.fold(init=0, (count, row) => {
    if row.is_failure {
      count + 1
    } else {
      count
    }
  })
}

///|
pub fn reliability_data_set_censored_count(dataset : ReliabilityDataSet) -> Int {
  dataset.rows.fold(init=0, (count, row) => {
    if row.is_censored {
      count + 1
    } else {
      count
    }
  })
}

///|
pub fn reliability_data_set_asset_count(dataset : ReliabilityDataSet) -> Int {
  let ids = dataset.rows.map(row => row.asset_id)
  let mut count = 0
  for id in ids {
    let mut seen = false
    for earlier in dataset.rows[:dataset.rows.length()].to_owned() {
      if earlier.asset_id == id {
        seen = true
      }
    }
    if seen {
      count += 1
    }
  }
  if ids.is_empty() {
    0
  } else {
    count / ids.length().max(1)
  }
}

///|
pub fn reliability_data_set_mean_quality(
  dataset : ReliabilityDataSet,
) -> Double {
  if dataset.rows.is_empty() {
    0.0
  } else {
    dataset.rows.fold(init=0.0, (sum, row) => sum + row.source_quality) /
    dataset.rows.length().to_double()
  }
}

///|
pub fn reliability_data_set_quality(dataset : ReliabilityDataSet) -> Double {
  let row_quality = reliability_data_set_mean_quality(dataset)
  let column_quality = if dataset.columns.is_empty() {
    1.0
  } else {
    dataset.columns.fold(init=0.0, (sum, column) => {
      sum + reliability_data_column_quality(column)
    }) /
    dataset.columns.length().to_double()
  }
  row_quality * column_quality
}

///|
pub fn reliability_data_set_observed_rows(
  dataset : ReliabilityDataSet,
) -> Array[ReliabilityDataRow] {
  dataset.rows.filter(row => reliability_data_row_is_observed(row))
}

///|
pub fn reliability_data_set_failure_rows(
  dataset : ReliabilityDataSet,
) -> Array[ReliabilityDataRow] {
  dataset.rows.filter(row => row.is_failure)
}

///|
pub fn reliability_data_set_asset_rows(
  dataset : ReliabilityDataSet,
  asset_id : Int,
) -> Array[ReliabilityDataRow] {
  dataset.rows.filter(row => row.asset_id == asset_id)
}

///|
pub fn reliability_data_set_time_slice(
  dataset : ReliabilityDataSet,
  start_time : Double,
  end_time : Double,
) -> Array[ReliabilityDataRow] {
  if end_time < start_time {
    abort("time slice end must not precede start")
  }
  dataset.rows.filter(row => {
    row.timestamp >= start_time && row.timestamp <= end_time
  })
}

///|
pub fn reliability_data_set_sorted_rows(
  dataset : ReliabilityDataSet,
) -> Array[ReliabilityDataRow] {
  let result = dataset.rows.copy()
  result.sort_by((left, right) => {
    if left.timestamp < right.timestamp {
      -1
    } else if left.timestamp > right.timestamp {
      1
    } else {
      0
    }
  })
  result
}

///|
pub fn reliability_data_set_has_time_regression(
  dataset : ReliabilityDataSet,
) -> Bool {
  let rows = reliability_data_set_sorted_rows(dataset)
  let mut previous = -1.0
  for row in rows {
    if row.timestamp < previous {
      return true
    }
    previous = row.timestamp
  }
  false
}

///|
/// A quality rule evaluated against a dataset.
pub struct ReliabilityDataRule {
  rule_id : String
  description : String
  threshold : Double
  weight : Double
  hard_fail : Bool
}

///|
pub fn reliability_data_rule(
  rule_id : String,
  description : String,
  threshold : Double,
  weight : Double,
  hard_fail : Bool,
) -> ReliabilityDataRule {
  if threshold < 0.0 || weight < 0.0 {
    abort("invalid reliability data rule")
  }
  { rule_id, description, threshold, weight, hard_fail }
}

///|
pub fn reliability_data_rule_passes(
  rule : ReliabilityDataRule,
  value : Double,
) -> Bool {
  value >= rule.threshold
}

///|
pub fn reliability_data_rule_weighted_score(
  rule : ReliabilityDataRule,
  value : Double,
) -> Double {
  rule.weight * value.max(0.0).min(1.0)
}

///|
pub struct ReliabilityDataRuleResult {
  rule_id : String
  observed : Double
  passed : Bool
  weighted_score : Double
  hard_fail : Bool
}

///|
pub fn reliability_data_rule_result(
  rule : ReliabilityDataRule,
  observed : Double,
) -> ReliabilityDataRuleResult {
  {
    rule_id: rule.rule_id,
    observed,
    passed: reliability_data_rule_passes(rule, observed),
    weighted_score: reliability_data_rule_weighted_score(rule, observed),
    hard_fail: rule.hard_fail,
  }
}

///|
pub fn reliability_data_rule_results_score(
  results : Array[ReliabilityDataRuleResult],
) -> Double {
  let weight = results.fold(init=0.0, (sum, result) => {
    if result.hard_fail {
      sum + 1.0
    } else {
      sum + result.weighted_score
    }
  })
  if results.is_empty() {
    1.0
  } else {
    weight / results.length().to_double()
  }
}

///|
pub fn reliability_data_rule_results_failed(
  results : Array[ReliabilityDataRuleResult],
) -> Array[String] {
  results.filter_map(result => {
    if result.passed {
      None
    } else {
      Some(result.rule_id)
    }
  })
}

///|
/// Result of a catalog validation run.
pub struct ReliabilityDataQualityReport {
  dataset_id : String
  quality_score : Double
  usable : Bool
  row_count : Int
  failure_count : Int
  censored_count : Int
  failed_rules : Array[String]
  warnings : Array[String]
}

///|
pub fn reliability_data_quality_report(
  dataset : ReliabilityDataSet,
  results : Array[ReliabilityDataRuleResult],
  minimum_quality : Double,
) -> ReliabilityDataQualityReport {
  let failed_rules = reliability_data_rule_results_failed(results)
  let hard_failure = results.fold(init=false, (failed, result) => {
    failed || (result.hard_fail && !result.passed)
  })
  let score = reliability_data_rule_results_score(results) *
    reliability_data_set_quality(dataset)
  let warnings = Array::new()
  if reliability_data_set_censored_count(dataset) >
    reliability_data_set_row_count(dataset) / 2 {
    warnings.push("censoring exceeds half of the dataset")
  }
  if reliability_data_set_mean_quality(dataset) < minimum_quality {
    warnings.push("row source quality is below threshold")
  }
  {
    dataset_id: dataset.dataset_id,
    quality_score: score,
    usable: score >= minimum_quality && !hard_failure,
    row_count: reliability_data_set_row_count(dataset),
    failure_count: reliability_data_set_failure_count(dataset),
    censored_count: reliability_data_set_censored_count(dataset),
    failed_rules,
    warnings,
  }
}

///|
pub fn reliability_data_report_has_blocker(
  report : ReliabilityDataQualityReport,
) -> Bool {
  !report.usable
}

///|
pub fn reliability_data_report_failure_fraction(
  report : ReliabilityDataQualityReport,
) -> Double {
  if report.row_count == 0 {
    0.0
  } else {
    report.failure_count.to_double() / report.row_count.to_double()
  }
}

///|
/// Feature transformation for condition-monitoring pipelines.
pub fn reliability_data_normalize(
  values : Array[Double],
  minimum : Double,
  maximum : Double,
) -> Array[Double] {
  if maximum == minimum {
    Array::make(values.length(), 0.0)
  } else {
    values.map(value => {
      ((value - minimum) / (maximum - minimum)).max(0.0).min(1.0)
    })
  }
}

///|
pub fn reliability_data_standardize(values : Array[Double]) -> Array[Double] {
  if values.is_empty() {
    Array::new()
  } else {
    let center = mean(values)
    let spread = variance(values).sqrt()
    if spread == 0.0 {
      Array::make(values.length(), 0.0)
    } else {
      values.map(v => (v - center) / spread)
    }
  }
}

///|
pub fn reliability_data_moving_average(
  values : Array[Double],
  window : Int,
) -> Array[Double] {
  if window < 1 || window > values.length().max(1) {
    abort("moving average window is outside data")
  }
  let result = Array::make(values.length(), 0.0)
  let mut sum = 0.0
  for i in 0..<values.length() {
    sum += values[i]
    if i >= window {
      sum -= values[i - window]
    }
    let denominator = (i + 1).min(window).to_double()
    result[i] = sum / denominator
  }
  result
}

///|
pub fn reliability_data_exponential_smoothing(
  values : Array[Double],
  alpha : Double,
) -> Array[Double] {
  if alpha < 0.0 || alpha > 1.0 {
    abort("smoothing alpha must be in [0, 1]")
  }
  if values.is_empty() {
    return Array::new()
  }
  let result = Array::make(values.length(), 0.0)
  result[0] = values[0]
  for i in 1..<values.length() {
    result[i] = alpha * values[i] + (1.0 - alpha) * result[i - 1]
  }
  result
}

///|
pub fn reliability_data_first_difference(
  values : Array[Double],
) -> Array[Double] {
  if values.length() < 2 {
    Array::new()
  } else {
    Array::makei(values.length() - 1, i => values[i + 1] - values[i])
  }
}

///|
pub fn reliability_data_outlier_flags(
  values : Array[Double],
  z_threshold : Double,
) -> Array[Bool] {
  if z_threshold <= 0.0 {
    abort("z threshold must be positive")
  }
  if values.is_empty() {
    return Array::new()
  }
  let center = mean(values)
  let spread = variance(values).sqrt()
  if spread == 0.0 {
    Array::make(values.length(), false)
  } else {
    values.map(value => ((value - center) / spread).abs() > z_threshold)
  }
}

///|
pub fn reliability_data_interpolate(
  left_time : Double,
  left_value : Double,
  right_time : Double,
  right_value : Double,
  target_time : Double,
) -> Double {
  if right_time == left_time {
    left_value
  } else {
    let fraction = (target_time - left_time) / (right_time - left_time)
    left_value + fraction * (right_value - left_value)
  }
}

///|
pub fn reliability_data_resample(
  rows : Array[ReliabilityDataRow],
  grid : Array[Double],
) -> Array[ReliabilityDataRow] {
  if rows.is_empty() || grid.is_empty() {
    return Array::new()
  }
  let ordered = rows.copy()
  ordered.sort_by((left, right) => {
    if left.timestamp < right.timestamp {
      -1
    } else if left.timestamp > right.timestamp {
      1
    } else {
      0
    }
  })
  grid.map(target => {
    let mut selected = ordered[0]
    for row in ordered {
      if row.timestamp <= target {
        selected = row
      }
    }
    { ..selected, timestamp: target }
  })
}

///|
pub fn reliability_data_window_count(
  start : Double,
  end : Double,
  width : Double,
  step : Double,
) -> Int {
  if end <= start || width <= 0.0 || step <= 0.0 {
    0
  } else {
    let mut count = 0
    let mut cursor = start
    while cursor + width <= end {
      count += 1
      cursor += step
    }
    count
  }
}

///|
pub fn reliability_data_window_means(
  rows : Array[ReliabilityDataRow],
  start : Double,
  end : Double,
  width : Double,
  step : Double,
) -> Array[Double] {
  if width <= 0.0 || step <= 0.0 || end <= start {
    abort("invalid data window")
  }
  let result = Array::new()
  let mut cursor = start
  while cursor + width <= end {
    let values = rows.filter_map(row => {
      if row.timestamp >= cursor && row.timestamp < cursor + width {
        Some(row.value)
      } else {
        None
      }
    })
    result.push(if values.is_empty() { 0.0 } else { mean(values) })
    cursor += step
  }
  result
}

///|
pub fn reliability_data_event_rate(
  rows : Array[ReliabilityDataRow],
  duration : Double,
) -> Double {
  if duration <= 0.0 {
    0.0
  } else {
    rows
    .fold(init=0, (count, row) => if row.is_failure { count + 1 } else { count })
    .to_double() /
    duration
  }
}

///|
pub fn reliability_data_quality_checksum(
  dataset : ReliabilityDataSet,
) -> Double {
  dataset.start_time +
  dataset.end_time +
  reliability_data_set_quality(dataset) * 100.0 +
  reliability_data_set_row_count(dataset).to_double() * 0.01 +
  reliability_data_set_failure_count(dataset).to_double()
}
