///|
/// A weighted measurement of an asset health indicator.
pub struct DegradationObservation {
  time : Double
  value : Double
  weight : Double
}

///|
pub fn degradation_observation(
  time : Double,
  value : Double,
  weight : Double,
) -> DegradationObservation {
  if time < 0.0 || weight <= 0.0 {
    abort("invalid degradation observation")
  }
  { time, value, weight }
}

///|
pub(all) enum DegradationLaw {
  DegradationLinear
  DegradationExponential
  DegradationPower
  DegradationLogistic
} derive(Debug, Eq)

///|
pub struct DegradationTrack {
  name : String
  observations : Array[DegradationObservation]
  lower_limit : Double
  upper_limit : Double
  direction : Int
}

///|
pub fn degradation_track(
  name : String,
  observations : Array[DegradationObservation],
  lower_limit : Double,
  upper_limit : Double,
  direction : Int,
) -> DegradationTrack {
  if observations.is_empty() ||
    lower_limit > upper_limit ||
    (direction != 1 && direction != -1) {
    abort("invalid degradation track")
  }
  let ordered = observations.copy()
  ordered.sort_by((left, right) => {
    if left.time < right.time {
      -1
    } else if left.time > right.time {
      1
    } else {
      0
    }
  })
  { name, observations: ordered, lower_limit, upper_limit, direction }
}

///|
pub fn degradation_count(track : DegradationTrack) -> Int {
  track.observations.length()
}

///|
pub fn degradation_first_time(track : DegradationTrack) -> Double {
  track.observations[0].time
}

///|
pub fn degradation_last_time(track : DegradationTrack) -> Double {
  track.observations[track.observations.length() - 1].time
}

///|
pub fn degradation_duration(track : DegradationTrack) -> Double {
  degradation_last_time(track) - degradation_first_time(track)
}

///|
pub fn degradation_times(track : DegradationTrack) -> Array[Double] {
  track.observations.map(observation => observation.time)
}

///|
pub fn degradation_values(track : DegradationTrack) -> Array[Double] {
  track.observations.map(observation => observation.value)
}

///|
pub fn degradation_weights(track : DegradationTrack) -> Array[Double] {
  track.observations.map(observation => observation.weight)
}

///|
pub fn degradation_weight(track : DegradationTrack) -> Double {
  track.observations.fold(init=0.0, (total, observation) => {
    total + observation.weight
  })
}

///|
pub fn degradation_mean(track : DegradationTrack) -> Double {
  weighted_mean(degradation_values(track), degradation_weights(track))
}

///|
pub fn degradation_variance(track : DegradationTrack) -> Double {
  weighted_variance(degradation_values(track), degradation_weights(track))
}

///|
pub fn degradation_standard_deviation(track : DegradationTrack) -> Double {
  degradation_variance(track).sqrt()
}

///|
pub fn degradation_minimum(track : DegradationTrack) -> Double {
  min_value(degradation_values(track))
}

///|
pub fn degradation_maximum(track : DegradationTrack) -> Double {
  max_value(degradation_values(track))
}

///|
pub fn degradation_range(track : DegradationTrack) -> Double {
  degradation_maximum(track) - degradation_minimum(track)
}

///|
pub fn degradation_limit(track : DegradationTrack) -> Double {
  if track.direction > 0 {
    track.upper_limit
  } else {
    track.lower_limit
  }
}

///|
pub fn degradation_margin(track : DegradationTrack, value : Double) -> Double {
  if track.direction > 0 {
    track.upper_limit - value
  } else {
    value - track.lower_limit
  }
}

///|
pub fn degradation_normalized_margin(
  track : DegradationTrack,
  value : Double,
) -> Double {
  let span = track.upper_limit - track.lower_limit
  if span == 0.0 {
    0.0
  } else {
    degradation_margin(track, value) / span
  }
}

///|
pub fn degradation_is_beyond_limit(
  track : DegradationTrack,
  value : Double,
) -> Bool {
  if track.direction > 0 {
    value >= track.upper_limit
  } else {
    value <= track.lower_limit
  }
}

///|
pub fn degradation_is_warning(
  track : DegradationTrack,
  value : Double,
  warning_fraction : Double,
) -> Bool {
  if warning_fraction < 0.0 || warning_fraction > 1.0 {
    abort("warning fraction must be in [0, 1]")
  }
  let threshold = if track.direction > 0 {
    track.upper_limit -
    (track.upper_limit - track.lower_limit) * warning_fraction
  } else {
    track.lower_limit +
    (track.upper_limit - track.lower_limit) * warning_fraction
  }
  if track.direction > 0 {
    value >= threshold
  } else {
    value <= threshold
  }
}

///|
pub fn degradation_out_of_bounds_count(track : DegradationTrack) -> Int {
  track.observations.fold(init=0, (count, observation) => {
    if observation.value < track.lower_limit ||
      observation.value > track.upper_limit {
      count + 1
    } else {
      count
    }
  })
}

///|
pub fn degradation_out_of_bounds_fraction(track : DegradationTrack) -> Double {
  degradation_out_of_bounds_count(track).to_double() /
  degradation_count(track).to_double()
}

///|
pub fn degradation_monotonicity(track : DegradationTrack) -> Double {
  if degradation_count(track) < 2 {
    1.0
  } else {
    let mut good = 0
    for i in 1..<degradation_count(track) {
      let change = track.observations[i].value - track.observations[i - 1].value
      if (track.direction > 0 && change >= 0.0) ||
        (track.direction < 0 && change <= 0.0) {
        good += 1
      }
    }
    good.to_double() / (degradation_count(track) - 1).to_double()
  }
}

///|
pub fn degradation_total_change(track : DegradationTrack) -> Double {
  if degradation_count(track) < 2 {
    0.0
  } else {
    track.observations[track.observations.length() - 1].value -
    track.observations[0].value
  }
}

///|
pub fn degradation_rate(track : DegradationTrack) -> Double {
  let duration = degradation_duration(track)
  if duration == 0.0 {
    0.0
  } else {
    degradation_total_change(track) / duration
  }
}

///|
pub fn degradation_absolute_rate(track : DegradationTrack) -> Double {
  degradation_rate(track).abs()
}

///|
pub fn degradation_directional_rate(track : DegradationTrack) -> Double {
  degradation_rate(track) * track.direction.to_double()
}

///|
pub fn degradation_last_value(track : DegradationTrack) -> Double {
  track.observations[track.observations.length() - 1].value
}

///|
pub fn degradation_first_value(track : DegradationTrack) -> Double {
  track.observations[0].value
}

///|
pub fn degradation_recent_rate(track : DegradationTrack, count : Int) -> Double {
  if count < 2 {
    abort("recent count must be at least two")
  }
  let start = (track.observations.length() - count).max(0)
  let points = Array::makei(track.observations.length() - start, i => {
    track.observations[start + i]
  })
  degradation_rate(
    degradation_track(
      track.name,
      points,
      track.lower_limit,
      track.upper_limit,
      track.direction,
    ),
  )
}

///|
pub struct DegradationFit {
  law : DegradationLaw
  coefficients : Array[Double]
  residuals : Array[Double]
  rmse : Double
  r_squared : Double
  converged : Bool
  iterations : Int
}

///|
pub fn degradation_fit(
  law : DegradationLaw,
  coefficients : Array[Double],
  residuals : Array[Double],
  rmse : Double,
  r_squared : Double,
  converged : Bool,
  iterations : Int,
) -> DegradationFit {
  { law, coefficients, residuals, rmse, r_squared, converged, iterations }
}

///|
fn degradation_regression(track : DegradationTrack) -> (Double, Double, Double) {
  let times = degradation_times(track)
  let values = degradation_values(track)
  let weights = degradation_weights(track)
  let mean_time = weighted_mean(times, weights)
  let mean_value = weighted_mean(values, weights)
  let mut numerator = 0.0
  let mut denominator = 0.0
  for i in 0..<times.length() {
    let dt = times[i] - mean_time
    numerator += weights[i] * dt * (values[i] - mean_value)
    denominator += weights[i] * dt * dt
  }
  let slope = if denominator == 0.0 { 0.0 } else { numerator / denominator }
  let intercept = mean_value - slope * mean_time
  let mut sse = 0.0
  let mut sst = 0.0
  for i in 0..<times.length() {
    let predicted = intercept + slope * times[i]
    sse += weights[i] * (values[i] - predicted) * (values[i] - predicted)
    sst += weights[i] * (values[i] - mean_value) * (values[i] - mean_value)
  }
  let r2 = if sst == 0.0 { 1.0 } else { 1.0 - sse / sst }
  (slope, intercept, r2)
}

///|
pub fn degradation_fit_linear(track : DegradationTrack) -> DegradationFit {
  let (slope, intercept, r2) = degradation_regression(track)
  let residuals = track.observations.map(observation => {
    observation.value - (intercept + slope * observation.time)
  })
  let rmse = mean(residuals.map(value => value * value)).sqrt()
  degradation_fit(
    DegradationLinear,
    [intercept, slope],
    residuals,
    rmse,
    r2,
    true,
    1,
  )
}

///|
pub fn degradation_fit_exponential(track : DegradationTrack) -> DegradationFit {
  let positive = track.observations.filter(observation => {
    observation.value > 0.0
  })
  if positive.length() < 2 {
    abort("exponential fit requires positive values")
  }
  let transformed = degradation_track(
    track.name,
    positive.map(observation => {
      degradation_observation(
        observation.time,
        @math.ln(observation.value),
        observation.weight,
      )
    }),
    @math.ln(track.lower_limit.max(1.0e-300)),
    @math.ln(track.upper_limit.max(1.0e-300)),
    track.direction,
  )
  let fit = degradation_fit_linear(transformed)
  let residuals = track.observations.map(observation => {
    let prediction = @math.exp(
      fit.coefficients[0] + fit.coefficients[1] * observation.time,
    )
    observation.value - prediction
  })
  let rmse = mean(residuals.map(value => value * value)).sqrt()
  degradation_fit(
    DegradationExponential,
    [@math.exp(fit.coefficients[0]), fit.coefficients[1]],
    residuals,
    rmse,
    fit.r_squared,
    fit.converged,
    fit.iterations,
  )
}

///|
pub fn degradation_fit_power(track : DegradationTrack) -> DegradationFit {
  let positive = track.observations.filter(observation => {
    observation.value > 0.0 && observation.time > 0.0
  })
  if positive.length() < 2 {
    abort("power fit requires positive time and value")
  }
  let transformed = degradation_track(
    track.name,
    positive.map(observation => {
      degradation_observation(
        @math.ln(observation.time),
        @math.ln(observation.value),
        observation.weight,
      )
    }),
    @math.ln(track.lower_limit.max(1.0e-300)),
    @math.ln(track.upper_limit.max(1.0e-300)),
    track.direction,
  )
  let fit = degradation_fit_linear(transformed)
  let residuals = track.observations.map(observation => {
    if observation.time <= 0.0 {
      0.0
    } else {
      let prediction = @math.exp(fit.coefficients[0]) *
        @math.pow(observation.time, fit.coefficients[1])
      observation.value - prediction
    }
  })
  let rmse = mean(residuals.map(value => value * value)).sqrt()
  degradation_fit(
    DegradationPower,
    [@math.exp(fit.coefficients[0]), fit.coefficients[1]],
    residuals,
    rmse,
    fit.r_squared,
    fit.converged,
    fit.iterations,
  )
}

///|
pub fn degradation_fit_best(track : DegradationTrack) -> DegradationFit {
  let candidates = [
    degradation_fit_linear(track),
    degradation_fit_exponential(track),
    degradation_fit_power(track),
  ]
  let mut best = candidates[0]
  for candidate in candidates[1:] {
    if candidate.rmse < best.rmse {
      best = candidate
    }
  }
  best
}

///|
pub fn degradation_fit_predict(fit : DegradationFit, time : Double) -> Double {
  match fit.law {
    DegradationLinear => fit.coefficients[0] + fit.coefficients[1] * time
    DegradationExponential =>
      fit.coefficients[0] * @math.exp(fit.coefficients[1] * time)
    DegradationPower =>
      if time <= 0.0 {
        0.0
      } else {
        fit.coefficients[0] * @math.pow(time, fit.coefficients[1])
      }
    DegradationLogistic => {
      let denominator = 1.0 +
        @math.exp(-fit.coefficients[1] * (time - fit.coefficients[2]))
      fit.coefficients[0] / denominator
    }
  }
}

///|
pub fn degradation_fit_derivative(
  fit : DegradationFit,
  time : Double,
) -> Double {
  match fit.law {
    DegradationLinear => fit.coefficients[1]
    DegradationExponential =>
      degradation_fit_predict(fit, time) * fit.coefficients[1]
    DegradationPower =>
      if time <= 0.0 {
        0.0
      } else {
        fit.coefficients[0] *
        fit.coefficients[1] *
        @math.pow(time, fit.coefficients[1] - 1.0)
      }
    DegradationLogistic => {
      let p = degradation_fit_predict(fit, time)
      fit.coefficients[1] * p * (1.0 - p / fit.coefficients[0])
    }
  }
}

///|
pub fn degradation_fit_acceleration(
  fit : DegradationFit,
  time : Double,
) -> Double {
  let left = degradation_fit_derivative(fit, time - 1.0e-3)
  let right = degradation_fit_derivative(fit, time + 1.0e-3)
  (right - left) / 2.0e-3
}

///|
pub fn degradation_fit_confidence_scale(
  fit : DegradationFit,
  confidence : Double,
) -> Double {
  if confidence <= 0.0 || confidence >= 1.0 {
    abort("confidence must be in (0, 1)")
  }
  let z = standard_normal_inv(0.5 + confidence / 2.0)
  z * fit.rmse
}

///|
pub fn degradation_fit_interval(
  fit : DegradationFit,
  time : Double,
  confidence : Double,
) -> MetricEstimate {
  let estimate = degradation_fit_predict(fit, time)
  let spread = degradation_fit_confidence_scale(fit, confidence)
  metric_estimate(
    estimate~,
    lower=(estimate - spread).max(0.0),
    upper=estimate + spread,
    confidence_level=confidence,
  )
}

///|
pub fn degradation_fit_grid(
  fit : DegradationFit,
  times : Array[Double],
) -> Array[Double] {
  times.map(time => degradation_fit_predict(fit, time))
}

///|
pub fn degradation_fit_derivative_grid(
  fit : DegradationFit,
  times : Array[Double],
) -> Array[Double] {
  times.map(time => degradation_fit_derivative(fit, time))
}

///|
pub fn degradation_fit_crossing_time(
  fit : DegradationFit,
  limit : Double,
  lower : Double,
  upper : Double,
) -> Double {
  if upper <= lower {
    abort("upper time must exceed lower time")
  }
  let increasing = degradation_fit_predict(fit, upper) >
    degradation_fit_predict(fit, lower)
  let mut left = lower
  let mut right = upper
  for _ in 0..<80 {
    let middle = (left + right) / 2.0
    let value = degradation_fit_predict(fit, middle)
    if (increasing && value < limit) || (!increasing && value > limit) {
      left = middle
    } else {
      right = middle
    }
  }
  (left + right) / 2.0
}

///|
pub fn degradation_remaining_life(
  track : DegradationTrack,
  fit : DegradationFit,
  current_time : Double,
) -> Double {
  let limit = degradation_limit(track)
  let crossing = degradation_fit_crossing_time(
    fit,
    limit,
    current_time,
    current_time + degradation_duration(track).max(1.0) * 100.0,
  )
  (crossing - current_time).max(0.0)
}

///|
pub fn degradation_rul_interval(
  track : DegradationTrack,
  fit : DegradationFit,
  current_time : Double,
  confidence : Double,
) -> MetricEstimate {
  let rul = degradation_remaining_life(track, fit, current_time)
  let spread = degradation_fit_confidence_scale(fit, confidence) /
    degradation_fit_derivative(fit, current_time).abs().max(1.0e-12)
  metric_estimate(
    estimate=rul,
    lower=(rul - spread).max(0.0),
    upper=rul + spread,
    confidence_level=confidence,
  )
}

///|
pub struct DegradationFeatureSet {
  mean : Double
  standard_deviation : Double
  slope : Double
  acceleration : Double
  monotonicity : Double
  recent_slope : Double
  threshold_margin : Double
  out_of_bounds_fraction : Double
  volatility : Double
  health_index : Double
}

///|
pub fn degradation_features(track : DegradationTrack) -> DegradationFeatureSet {
  let fit = degradation_fit_linear(track)
  let last_time = degradation_last_time(track)
  let margin = degradation_normalized_margin(
    track,
    degradation_last_value(track),
  )
  let volatility = if degradation_mean(track) == 0.0 {
    degradation_standard_deviation(track)
  } else {
    degradation_standard_deviation(track) / degradation_mean(track).abs()
  }
  {
    mean: degradation_mean(track),
    standard_deviation: degradation_standard_deviation(track),
    slope: degradation_fit_derivative(fit, last_time),
    acceleration: degradation_fit_acceleration(fit, last_time),
    monotonicity: degradation_monotonicity(track),
    recent_slope: degradation_recent_rate(
      track,
      degradation_count(track).min(5).max(2),
    ),
    threshold_margin: margin,
    out_of_bounds_fraction: degradation_out_of_bounds_fraction(track),
    volatility,
    health_index: degradation_health_index(track),
  }
}

///|
pub fn degradation_health_index(track : DegradationTrack) -> Double {
  let margin = degradation_normalized_margin(
    track,
    degradation_last_value(track),
  )
  let monotonicity = degradation_monotonicity(track)
  let volatility = degradation_standard_deviation(track) /
    degradation_range(track).max(1.0e-12)
  let direction_score = if degradation_directional_rate(track) >= 0.0 {
    1.0
  } else {
    0.0
  }
  (0.55 * margin.max(0.0).min(1.0) +
  0.30 * monotonicity +
  0.15 * (1.0 - volatility).max(0.0) * direction_score).min(1.0)
}

///|
pub fn degradation_health_label(index : Double) -> String {
  if index >= 0.85 {
    "healthy"
  } else if index >= 0.65 {
    "watch"
  } else if index >= 0.40 {
    "degraded"
  } else {
    "critical"
  }
}

///|
pub fn degradation_health_gap(
  track : DegradationTrack,
  target : Double,
) -> Double {
  (target - degradation_health_index(track)).max(0.0)
}

///|
pub fn degradation_warning_score(
  track : DegradationTrack,
  warning_fraction : Double,
) -> Double {
  if degradation_is_beyond_limit(track, degradation_last_value(track)) {
    1.0
  } else if degradation_is_warning(
      track,
      degradation_last_value(track),
      warning_fraction,
    ) {
    0.75
  } else {
    0.0
  }
}

///|
pub fn degradation_alert_level(track : DegradationTrack) -> Int {
  let index = degradation_health_index(track)
  if index < 0.4 {
    3
  } else if index < 0.65 {
    2
  } else if index < 0.85 {
    1
  } else {
    0
  }
}

///|
pub fn degradation_change_points(
  track : DegradationTrack,
  threshold : Double,
) -> Array[Int] {
  if threshold < 0.0 {
    abort("change threshold must be non-negative")
  }
  let result = []
  if degradation_count(track) >= 3 {
    for i in 1..<(degradation_count(track) - 1) {
      let before = track.observations[i].value - track.observations[i - 1].value
      let after = track.observations[i + 1].value - track.observations[i].value
      if (after - before).abs() >= threshold {
        result.push(i)
      }
    }
  }
  result
}

///|
pub fn degradation_residual_autocorrelation(
  _track : DegradationTrack,
  fit : DegradationFit,
  lag : Int,
) -> Double {
  autocorrelation_lag(fit.residuals, lag)
}

///|
pub fn degradation_residual_normalized(fit : DegradationFit) -> Array[Double] {
  let center = mean(fit.residuals)
  let scale = variance(fit.residuals, unbiased=false).sqrt().max(1.0e-12)
  fit.residuals.map(value => (value - center) / scale)
}

///|
pub fn degradation_residual_abs_mean(fit : DegradationFit) -> Double {
  mean(fit.residuals.map(value => value.abs()))
}

///|
pub fn degradation_residual_bias(fit : DegradationFit) -> Double {
  mean(fit.residuals)
}

///|
pub fn degradation_residual_max(fit : DegradationFit) -> Double {
  max_value(fit.residuals.map(value => value.abs()))
}

///|
pub fn degradation_fit_score(fit : DegradationFit) -> Double {
  fit.r_squared.max(0.0).min(1.0) * @math.exp(-fit.rmse.abs())
}

///|
pub fn degradation_fit_is_adequate(
  fit : DegradationFit,
  maximum_rmse : Double,
  minimum_r_squared : Double,
) -> Bool {
  fit.rmse <= maximum_rmse &&
  fit.r_squared >= minimum_r_squared &&
  fit.converged
}

///|
pub fn degradation_fit_rank(
  fits : Array[DegradationFit],
) -> Array[DegradationFit] {
  let result = fits.copy()
  result.sort_by((left, right) => {
    let left_score = degradation_fit_score(left)
    let right_score = degradation_fit_score(right)
    if left_score > right_score {
      -1
    } else if left_score < right_score {
      1
    } else {
      0
    }
  })
  result
}

///|
pub fn degradation_track_checksum(track : DegradationTrack) -> Double {
  track.observations.fold(init=0.0, (total, observation) => {
    total + observation.time + observation.value + observation.weight
  })
}

///|
pub fn degradation_fit_checksum(fit : DegradationFit) -> Double {
  fit.coefficients.fold(init=fit.rmse + fit.r_squared, (total, value) => {
    total + value
  }) +
  fit.residuals.fold(init=0.0, (total, value) => total + value)
}

///|
pub fn degradation_track_resample(
  track : DegradationTrack,
  step : Double,
) -> DegradationTrack {
  if step <= 0.0 {
    abort("resampling step must be positive")
  }
  let start = degradation_first_time(track)
  let stop = degradation_last_time(track)
  let count = ((stop - start) / step).floor().to_int() + 1
  let values = Array::makei(count, i => {
    let time = start + i.to_double() * step
    let mut nearest = track.observations[0]
    let mut distance = (nearest.time - time).abs()
    for observation in track.observations[1:] {
      let candidate_distance = (observation.time - time).abs()
      if candidate_distance < distance {
        nearest = observation
        distance = candidate_distance
      }
    }
    degradation_observation(time, nearest.value, nearest.weight)
  })
  degradation_track(
    track.name,
    values,
    track.lower_limit,
    track.upper_limit,
    track.direction,
  )
}

///|
pub fn degradation_track_window(
  track : DegradationTrack,
  start : Double,
  stop : Double,
) -> DegradationTrack {
  if stop <= start {
    abort("window stop must exceed start")
  }
  degradation_track(
    track.name,
    track.observations.filter(observation => {
      observation.time >= start && observation.time <= stop
    }),
    track.lower_limit,
    track.upper_limit,
    track.direction,
  )
}

///|
pub fn degradation_track_append(
  track : DegradationTrack,
  observation : DegradationObservation,
) -> DegradationTrack {
  degradation_track(
    track.name,
    track.observations + [observation],
    track.lower_limit,
    track.upper_limit,
    track.direction,
  )
}

///|
pub fn degradation_track_shift(
  track : DegradationTrack,
  time_shift : Double,
  value_shift : Double,
) -> DegradationTrack {
  degradation_track(
    track.name,
    track.observations.map(observation => {
      degradation_observation(
        observation.time + time_shift,
        observation.value + value_shift,
        observation.weight,
      )
    }),
    track.lower_limit + value_shift,
    track.upper_limit + value_shift,
    track.direction,
  )
}

///|
pub fn degradation_track_scale(
  track : DegradationTrack,
  value_scale : Double,
) -> DegradationTrack {
  if value_scale <= 0.0 {
    abort("value scale must be positive")
  }
  degradation_track(
    track.name,
    track.observations.map(observation => {
      degradation_observation(
        observation.time,
        observation.value * value_scale,
        observation.weight,
      )
    }),
    track.lower_limit * value_scale,
    track.upper_limit * value_scale,
    track.direction,
  )
}

///|
pub fn degradation_track_merge(
  left : DegradationTrack,
  right : DegradationTrack,
) -> DegradationTrack {
  if left.lower_limit != right.lower_limit ||
    left.upper_limit != right.upper_limit ||
    left.direction != right.direction {
    abort("degradation tracks have incompatible limits")
  }
  degradation_track(
    left.name,
    left.observations + right.observations,
    left.lower_limit,
    left.upper_limit,
    left.direction,
  )
}

///|
pub fn degradation_track_difference(
  left : DegradationTrack,
  right : DegradationTrack,
) -> DegradationTrack {
  if degradation_count(left) != degradation_count(right) {
    abort("track lengths must match")
  }
  degradation_track(
    left.name,
    Array::makei(degradation_count(left), i => {
      degradation_observation(
        left.observations[i].time,
        left.observations[i].value - right.observations[i].value,
        left.observations[i].weight,
      )
    }),
    left.lower_limit - right.upper_limit,
    left.upper_limit - right.lower_limit,
    left.direction,
  )
}

///|
pub fn degradation_track_ratio(
  left : DegradationTrack,
  right : DegradationTrack,
) -> DegradationTrack {
  if degradation_count(left) != degradation_count(right) {
    abort("track lengths must match")
  }
  degradation_track(
    left.name,
    Array::makei(degradation_count(left), i => {
      degradation_observation(
        left.observations[i].time,
        left.observations[i].value / right.observations[i].value.max(1.0e-300),
        left.observations[i].weight,
      )
    }),
    0.0,
    1.0e300,
    left.direction,
  )
}

///|
pub struct DegradationFleetSummary {
  track_count : Int
  healthy_count : Int
  warning_count : Int
  critical_count : Int
  average_health : Double
  minimum_health : Double
  maximum_risk : Double
}

///|
pub fn degradation_fleet_summary(
  tracks : Array[DegradationTrack],
  warning_fraction : Double,
) -> DegradationFleetSummary {
  if tracks.is_empty() {
    abort("tracks must not be empty")
  }
  let health = tracks.map(track => degradation_health_index(track))
  let warning = tracks.fold(init=0, (count, track) => {
    if degradation_is_warning(
        track,
        degradation_last_value(track),
        warning_fraction,
      ) {
      count + 1
    } else {
      count
    }
  })
  let critical = health.fold(init=0, (count, value) => {
    if value < 0.4 {
      count + 1
    } else {
      count
    }
  })
  {
    track_count: tracks.length(),
    healthy_count: health.fold(init=0, (count, value) => {
      if value >= 0.85 {
        count + 1
      } else {
        count
      }
    }),
    warning_count: warning,
    critical_count: critical,
    average_health: mean(health),
    minimum_health: min_value(health),
    maximum_risk: 1.0 - min_value(health),
  }
}

///|
pub fn degradation_fleet_health(
  tracks : Array[DegradationTrack],
) -> Array[Double] {
  tracks.map(track => degradation_health_index(track))
}

///|
pub fn degradation_fleet_risk(
  tracks : Array[DegradationTrack],
) -> Array[Double] {
  tracks.map(track => 1.0 - degradation_health_index(track))
}

///|
pub fn degradation_fleet_rank(
  tracks : Array[DegradationTrack],
) -> Array[DegradationTrack] {
  let result = tracks.copy()
  result.sort_by((left, right) => {
    let left_risk = 1.0 - degradation_health_index(left)
    let right_risk = 1.0 - degradation_health_index(right)
    if left_risk > right_risk {
      -1
    } else if left_risk < right_risk {
      1
    } else {
      0
    }
  })
  result
}

///|
pub fn degradation_fleet_priorities(
  tracks : Array[DegradationTrack],
  budget : Int,
) -> Array[DegradationTrack] {
  if budget < 0 {
    abort("budget must be non-negative")
  }
  let ranked = degradation_fleet_rank(tracks)
  Array::makei(budget.min(ranked.length()), i => ranked[i])
}

///|
pub fn degradation_fleet_checksum(tracks : Array[DegradationTrack]) -> Double {
  tracks.fold(init=0.0, (total, track) => {
    total + degradation_track_checksum(track) + degradation_health_index(track)
  })
}
