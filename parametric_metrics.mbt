///|
pub fn model_metric(
  model : ReliabilityModel,
  time : Double,
  confidence_level : Double,
) -> MetricEstimate {
  let estimate = model.survival(time)
  let standard_error = (estimate * (1.0 - estimate)).sqrt()
  let z = standard_normal_inv(0.5 + confidence_level / 2.0)
  metric_estimate(
    estimate~,
    lower=(estimate - z * standard_error).max(0.0),
    upper=(estimate + z * standard_error).min(1.0),
    confidence_level~,
  )
}

///|
pub fn model_mean(model : ReliabilityModel) -> Double {
  match model {
    ExponentialModel(value) => value.mtbf()
    WeibullModel(value) => value.mtbf()
    LognormalModel(value) => value.mtbf()
    GammaModel(value) => value.mean()
    LogLogisticModel(value) => value.mean()
  }
}

///|
pub fn model_quantile(model : ReliabilityModel, probability : Double) -> Double {
  match model {
    ExponentialModel(value) => value.quantile(probability)
    WeibullModel(value) => value.quantile(probability)
    LognormalModel(value) => value.quantile(probability)
    GammaModel(value) => value.quantile(probability)
    LogLogisticModel(value) => value.quantile(probability)
  }
}

///|
pub fn model_hazard(model : ReliabilityModel, time : Double) -> Double {
  match model {
    ExponentialModel(value) => value.failure_rate(time)
    WeibullModel(value) => value.failure_rate(time)
    LognormalModel(value) => {
      let survival = value.reliability(time)
      if survival <= 1.0e-300 {
        1.0e300
      } else {
        value.pdf(time) / survival
      }
    }
    GammaModel(value) => value.failure_rate(time)
    LogLogisticModel(value) => value.hazard(time)
  }
}

///|
pub fn reliability_at(
  model : ReliabilityModel,
  times : Array[Double],
) -> Array[Double] {
  times.map(time => model.survival(time))
}

///|
pub fn hazard_curve(
  model : ReliabilityModel,
  times : Array[Double],
) -> Array[Double] {
  times.map(time => model_hazard(model, time))
}

///|
pub fn model_brier_score(
  model : ReliabilityModel,
  records : Array[LifeObservation],
  time : Double,
) -> Double {
  let mut total = 0.0
  let mut weight = 0.0
  let prediction = model.survival(time)
  for record in records {
    if record.time >= time || record.is_failure() {
      let observed = if record.is_failure() && record.time <= time {
        0.0
      } else {
        1.0
      }
      total += record.weight * (prediction - observed) * (prediction - observed)
      weight += record.weight
    }
  }
  if weight == 0.0 {
    0.0
  } else {
    total / weight
  }
}

///|
pub fn integrated_brier_score(
  model : ReliabilityModel,
  records : Array[LifeObservation],
  start : Double,
  stop : Double,
  steps : Int,
) -> Double {
  let grid = linspace(start, stop, steps)
  let scores = grid.map(time => model_brier_score(model, records, time))
  mean(scores)
}

///|
pub fn model_calibration_error(
  model : ReliabilityModel,
  records : Array[LifeObservation],
  bins : Int,
) -> Double {
  if bins <= 0 {
    abort("bins must be positive")
  }
  let maximum = max_value(records.map(record => record.time))
  let grid = linspace(0.0, maximum, bins + 1)
  let mut total = 0.0
  for i in 0..<bins {
    let left = grid[i]
    let right = grid[i + 1]
    let group = records.filter(record => {
      record.time >= left && record.time <= right
    })
    if !group.is_empty() {
      let observed = group.fold(init=0.0, (s, record) => {
          let contribution = if record.is_failure() { 0.0 } else { 1.0 }
          s + contribution
        }) /
        group.length().to_double()
      total += (model.survival((left + right) / 2.0) - observed).abs()
    } else {
      ()
    }
  }
  total / bins.to_double()
}
