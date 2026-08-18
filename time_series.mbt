///|
/// Time-indexed reliability metric.
pub struct TimeSeriesPoint {
  time : Double
  value : Double
  lower : Double
  upper : Double
}

///|
pub fn time_series_point(
  time~ : Double,
  value~ : Double,
  lower~ : Double,
  upper~ : Double,
) -> TimeSeriesPoint {
  { time, value, lower, upper }
}

///|
pub struct ForecastResult {
  points : Array[TimeSeriesPoint]
  algorithm : String
  residual_scale : Double
}

///|
pub fn forecast_result(
  points~ : Array[TimeSeriesPoint],
  algorithm~ : String,
  residual_scale~ : Double,
) -> ForecastResult {
  { points, algorithm, residual_scale }
}

///|
pub fn exponential_smoothing(
  values : Array[Double],
  alpha : Double,
) -> Array[Double] {
  if values.is_empty() || alpha <= 0.0 || alpha > 1.0 {
    abort("invalid smoothing input")
  }
  let result = Array::make(values.length(), values[0])
  let mut level = values[0]
  for i in 1..<values.length() {
    level = alpha * values[i] + (1.0 - alpha) * level
    result[i] = level
  }
  result
}

///|
pub fn holt_linear_trend(
  values : Array[Double],
  alpha : Double,
  beta : Double,
) -> Array[Double] {
  if values.length() < 2 ||
    alpha <= 0.0 ||
    alpha > 1.0 ||
    beta <= 0.0 ||
    beta > 1.0 {
    abort("invalid Holt parameters")
  }
  let result = Array::make(values.length(), values[0])
  let mut level = values[0]
  let mut trend = values[1] - values[0]
  result[0] = level
  for i in 1..<values.length() {
    let previous = level
    level = alpha * values[i] + (1.0 - alpha) * (level + trend)
    trend = beta * (level - previous) + (1.0 - beta) * trend
    result[i] = level + trend
  }
  result
}

///|
pub fn seasonal_difference(
  values : Array[Double],
  period : Int,
) -> Array[Double] {
  if period <= 0 || period >= values.length() {
    abort("invalid seasonal period")
  }
  Array::makei(values.length() - period, i => values[i + period] - values[i])
}

///|
pub fn first_difference(values : Array[Double]) -> Array[Double] {
  if values.length() < 2 {
    abort("difference requires two values")
  }
  Array::makei(values.length() - 1, i => values[i + 1] - values[i])
}

///|
pub fn rolling_quantile(
  values : Array[Double],
  window : Int,
  p : Double,
) -> Array[Double] {
  if window <= 0 || window > values.length() {
    abort("invalid rolling window")
  }
  Array::makei(values.length() - window + 1, i => {
    quantile(values[i:i + window].to_owned(), p)
  })
}

///|
pub fn detect_level_shift(
  values : Array[Double],
  minimum_segment : Int,
) -> Int? {
  if values.length() < 2 * minimum_segment || minimum_segment < 2 {
    abort("invalid segment size")
  }
  let mut best_index = 0
  let mut best_score = 0.0
  for split in minimum_segment..<(values.length() - minimum_segment + 1) {
    let left = values[:split].to_owned()
    let right = values[split:].to_owned()
    let score = (mean(left) - mean(right)).abs() /
      variance(values).sqrt().max(1.0e-12)
    if score > best_score {
      best_score = score
      best_index = split
    } else {
      ()
    }
  }
  if best_score > 1.0 {
    Some(best_index)
  } else {
    None
  }
}

///|
pub fn simple_forecast(
  values : Array[Double],
  horizon : Int,
  alpha : Double,
  step : Double,
) -> ForecastResult {
  if horizon <= 0 || values.is_empty() {
    abort("invalid forecast horizon")
  }
  let smoothed = exponential_smoothing(values, alpha)
  let last = smoothed[smoothed.length() - 1]
  let recent = if values.length() >= 2 {
    (values[values.length() - 1] - values[values.length() - 2]) / step
  } else {
    0.0
  }
  let error = variance(values.map(value => value - mean(values))).sqrt()
  let points = Array::makei(horizon, i => {
    let forecast = last + recent * (i + 1).to_double() * step
    let margin = 1.96 * error * (i + 1).to_double().sqrt()
    time_series_point(
      time=(i + 1).to_double() * step,
      value=forecast,
      lower=forecast - margin,
      upper=forecast + margin,
    )
  })
  forecast_result(points~, algorithm="simple-exponential", residual_scale=error)
}

///|
pub fn forecast_accuracy(
  actual : Array[Double],
  predicted : Array[Double],
) -> MetricEstimate {
  if actual.length() != predicted.length() || actual.is_empty() {
    abort("forecast arrays must match")
  }
  let errors = Array::makei(actual.length(), i => {
    (actual[i] - predicted[i]).abs()
  })
  let value = mean(errors)
  let se = variance(errors, unbiased=false).sqrt() /
    actual.length().to_double().sqrt()
  metric_estimate(
    estimate=value,
    lower=(value - 1.96 * se).max(0.0),
    upper=value + 1.96 * se,
    confidence_level=0.95,
  )
}

///|
pub fn seasonal_index(values : Array[Double], period : Int) -> Array[Double] {
  if period <= 0 || values.length() < period {
    abort("invalid seasonal period")
  }
  let baseline = mean(values)
  Array::makei(period, i => {
    let seasonal : Array[Double] = []
    let mut index = i
    while index < values.length() {
      seasonal.push(values[index])
      index += period
    }
    mean(seasonal) / baseline
  })
}
