///|
/// Bounded one-dimensional optimization utilities for life-model calibration.
pub struct OptimizationResult {
  parameter : Double
  objective : Double
  iterations : Int
  converged : Bool
}

///|
pub fn optimization_result(
  parameter~ : Double,
  objective~ : Double,
  iterations~ : Int,
  converged~ : Bool,
) -> OptimizationResult {
  { parameter, objective, iterations, converged }
}

///|
pub fn golden_section_minimize(
  lower : Double,
  upper : Double,
  objective : (Double) -> Double,
  tolerance : Double,
) -> OptimizationResult {
  if upper <= lower || tolerance <= 0.0 {
    abort("invalid optimization interval")
  }
  let ratio = (5.0.sqrt() - 1.0) / 2.0
  let mut left = lower
  let mut right = upper
  let mut x1 = right - ratio * (right - left)
  let mut x2 = left + ratio * (right - left)
  let mut f1 = objective(x1)
  let mut f2 = objective(x2)
  let mut iterations = 0
  while (right - left).abs() > tolerance && iterations < 500 {
    if f1 > f2 {
      left = x1
      x1 = x2
      f1 = f2
      x2 = left + ratio * (right - left)
      f2 = objective(x2)
    } else {
      right = x2
      x2 = x1
      f2 = f1
      x1 = right - ratio * (right - left)
      f1 = objective(x1)
    }
    iterations += 1
  }
  let parameter = (left + right) / 2.0
  optimization_result(
    parameter~,
    objective=objective(parameter),
    iterations~,
    converged=iterations < 500,
  )
}

///|
pub fn grid_minimize(
  grid : Array[Double],
  objective : (Double) -> Double,
) -> OptimizationResult {
  if grid.is_empty() {
    abort("grid optimizer requires points")
  }
  let mut best = grid[0]
  let mut best_value = objective(best)
  for value in grid[1:] {
    let current = objective(value)
    if current < best_value {
      best = value
      best_value = current
    }
  }
  optimization_result(
    parameter=best,
    objective=best_value,
    iterations=grid.length(),
    converged=true,
  )
}

///|
pub fn fit_scale_by_mle(
  records : Array[LifeObservation],
  shape : Double,
) -> OptimizationResult {
  let objective = scale => {
    let scale_model = Weibull::new(scale, shape)
    -ReliabilityModel::WeibullModel(scale_model).log_likelihood(records)
  }
  golden_section_minimize(
    1.0e-6,
    total_exposure(records).max(1.0),
    objective,
    1.0e-8,
  )
}

///|
pub fn line_search(
  initial : Double,
  direction : Double,
  objective : (Double) -> Double,
) -> Double {
  let result = golden_section_minimize(
    initial.min(initial + direction),
    initial.max(initial + direction),
    objective,
    1.0e-8,
  )
  result.parameter
}

///|
pub fn finite_gradient(
  point : Array[Double],
  objective : (Array[Double]) -> Double,
  step : Double,
) -> Array[Double] {
  Array::makei(point.length(), i => {
    let plus = point.copy()
    plus[i] += step
    let minus = point.copy()
    minus[i] -= step
    (objective(plus) - objective(minus)) / (2.0 * step)
  })
}

///|
pub fn coordinate_descent(
  initial : Array[Double],
  objective : (Array[Double]) -> Double,
  step : Double,
  iterations : Int,
) -> Array[Double] {
  let point = initial.copy()
  let mut current = objective(point)
  for _ in 0..<iterations {
    for i in 0..<point.length() {
      let plus = point.copy()
      plus[i] += step
      let minus = point.copy()
      minus[i] -= step
      let plus_value = objective(plus)
      let minus_value = objective(minus)
      if plus_value < current && plus_value <= minus_value {
        point[i] += step
        current = plus_value
      } else if minus_value < current {
        point[i] -= step
        current = minus_value
      }
    }
  }
  point
}
