///|
/// Crow-AMSAA / Duane reliability-growth model.
pub struct ReliabilityGrowthModel {
  intercept : Double
  shape : Double
  scale : Double
  fit : RegressionResult
}

///|
pub fn reliability_growth_model(
  intercept~ : Double,
  shape~ : Double,
  scale~ : Double,
  fit~ : RegressionResult,
) -> ReliabilityGrowthModel {
  { intercept, shape, scale, fit }
}

///|
pub fn fit_crow_amsaa(times : Array[Double]) -> ReliabilityGrowthModel {
  if times.length() < 4 {
    abort("Crow-AMSAA fit requires four failure times")
  }
  let sorted = times.copy()
  sorted.sort()
  let cumulative = Array::makei(sorted.length(), i => i.to_double() + 1.0)
  let fit = linear_regression(
    sorted.map(value => @math.ln(value)),
    cumulative.map(value => @math.ln(value)),
  )
  let shape = fit.coefficients[1]
  let scale = @math.exp(-fit.coefficients[0] / shape)
  reliability_growth_model(intercept=fit.coefficients[0], shape~, scale~, fit~)
}

///|
pub fn ReliabilityGrowthModel::expected_failures(
  self : ReliabilityGrowthModel,
  time : Double,
) -> Double {
  @math.pow(time / self.scale, self.shape)
}

///|
pub fn ReliabilityGrowthModel::failure_intensity(
  self : ReliabilityGrowthModel,
  time : Double,
) -> Double {
  if time <= 0.0 {
    0.0
  } else {
    self.shape / self.scale * @math.pow(time / self.scale, self.shape - 1.0)
  }
}

///|
pub fn ReliabilityGrowthModel::mtbf(
  self : ReliabilityGrowthModel,
  time : Double,
) -> Double {
  let intensity = self.failure_intensity(time)
  if intensity <= 0.0 {
    1.0e300
  } else {
    1.0 / intensity
  }
}

///|
pub fn ReliabilityGrowthModel::improvement_factor(
  self : ReliabilityGrowthModel,
  start : Double,
  end : Double,
) -> Double {
  self.mtbf(end) / self.mtbf(start)
}

///|
pub fn ReliabilityGrowthModel::predict_time_for_failures(
  self : ReliabilityGrowthModel,
  failures : Double,
) -> Double {
  self.scale * @math.pow(failures.max(0.0), 1.0 / self.shape)
}

///|
pub fn ReliabilityGrowthModel::reliability_growth_confidence(
  self : ReliabilityGrowthModel,
  time : Double,
  confidence : Double,
) -> MetricEstimate {
  let estimate = self.expected_failures(time)
  let error = self.fit.residual_sum_squares.sqrt().max(0.1)
  let z = standard_normal_inv(0.5 + confidence / 2.0)
  metric_estimate(
    estimate~,
    lower=(estimate - z * error).max(0.0),
    upper=estimate + z * error,
    confidence_level=confidence,
  )
}

///|
pub fn duane_average_failure_rate(times : Array[Double]) -> Array[Double] {
  let sorted = times.copy()
  sorted.sort()
  Array::makei(sorted.length(), i => (i + 1).to_double() / sorted[i])
}

///|
pub fn failure_rate_trend(times : Array[Double]) -> Double {
  let model = fit_crow_amsaa(times)
  model.shape - 1.0
}

///|
pub fn is_improving(model : ReliabilityGrowthModel) -> Bool {
  model.shape < 1.0
}

///|
pub fn growth_phase(model : ReliabilityGrowthModel) -> String {
  if model.shape < 0.95 {
    "improving"
  } else if model.shape > 1.05 {
    "degrading"
  } else {
    "stable"
  }
}

///|
pub fn segment_failure_times(
  times : Array[Double],
  segments : Int,
) -> Array[Array[Double]] {
  if segments <= 0 || segments > times.length() {
    abort("invalid segment count")
  }
  let sorted = times.copy()
  sorted.sort()
  Array::makei(segments, i => {
    let start = i * sorted.length() / segments
    let stop = (i + 1) * sorted.length() / segments
    sorted[start:stop].to_owned()
  })
}
