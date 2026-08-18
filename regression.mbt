///|
/// Ordinary and weighted least-squares result for engineering covariates.
pub struct RegressionResult {
  coefficients : Array[Double]
  standard_errors : Array[Double]
  fitted : Array[Double]
  residuals : Array[Double]
  r_squared : Double
  adjusted_r_squared : Double
  residual_sum_squares : Double
  observations : Int
}

///|
pub fn regression_result(
  coefficients~ : Array[Double],
  standard_errors~ : Array[Double],
  fitted~ : Array[Double],
  residuals~ : Array[Double],
  r_squared~ : Double,
  adjusted_r_squared~ : Double,
  residual_sum_squares~ : Double,
  observations~ : Int,
) -> RegressionResult {
  {
    coefficients,
    standard_errors,
    fitted,
    residuals,
    r_squared,
    adjusted_r_squared,
    residual_sum_squares,
    observations,
  }
}

///|
pub fn linear_regression(
  x : Array[Double],
  y : Array[Double],
) -> RegressionResult {
  if x.length() != y.length() || x.length() < 3 {
    abort("linear regression requires three paired values")
  }
  let x_mean = mean(x)
  let y_mean = mean(y)
  let mut cross = 0.0
  let mut sum_x = 0.0
  for i in 0..<x.length() {
    cross += (x[i] - x_mean) * (y[i] - y_mean)
    sum_x += (x[i] - x_mean) * (x[i] - x_mean)
  }
  if sum_x == 0.0 {
    abort("regressor has no variation")
  }
  let slope = cross / sum_x
  let intercept = y_mean - slope * x_mean
  regression_from_coefficients(x, y, [intercept, slope], 2)
}

///|
pub fn weighted_linear_regression(
  x : Array[Double],
  y : Array[Double],
  weights : Array[Double],
) -> RegressionResult {
  if x.length() != y.length() ||
    x.length() != weights.length() ||
    x.length() < 3 {
    abort("weighted regression requires equal arrays")
  }
  let total = compensated_sum(weights)
  let x_mean = weighted_sum(x, weights) / total
  let y_mean = weighted_sum(y, weights) / total
  let mut cross = 0.0
  let mut sum_x = 0.0
  for i in 0..<x.length() {
    cross += weights[i] * (x[i] - x_mean) * (y[i] - y_mean)
    sum_x += weights[i] * (x[i] - x_mean) * (x[i] - x_mean)
  }
  let slope = cross / sum_x
  let intercept = y_mean - slope * x_mean
  regression_from_coefficients(x, y, [intercept, slope], 2)
}

///|
pub fn polynomial_regression(
  x : Array[Double],
  y : Array[Double],
  degree : Int,
) -> RegressionResult {
  if degree < 1 || x.length() <= degree {
    abort("insufficient data for polynomial regression")
  }
  let matrix : Array[Array[Double]] = []
  let rhs : Array[Double] = []
  for row in 0..<=degree {
    let values : Array[Double] = []
    for col in 0..<=degree {
      let mut sum = 0.0
      for value in x {
        sum += @math.pow(value, (row + col).to_double())
      }
      values.push(sum)
    }
    matrix.push(values)
    let mut target = 0.0
    for i in 0..<x.length() {
      target += y[i] * @math.pow(x[i], row.to_double())
    }
    rhs.push(target)
  }
  let coefficients = solve_linear_system(matrix, rhs)
  regression_from_coefficients(x, y, coefficients, degree + 1)
}

///|
fn regression_from_coefficients(
  x : Array[Double],
  y : Array[Double],
  coefficients : Array[Double],
  parameter_count : Int,
) -> RegressionResult {
  let fitted = Array::makei(x.length(), i => {
    coefficients.foldi(init=0.0, (power, total, coefficient) => {
      total + coefficient * @math.pow(x[i], power.to_double())
    })
  })
  let residuals = Array::makei(y.length(), i => y[i] - fitted[i])
  let rss = dot(residuals, residuals)
  let total = y.map(value => value - mean(y))
  let tss = dot(total, total)
  let r2 = if tss == 0.0 { 1.0 } else { 1.0 - rss / tss }
  let n = x.length().to_double()
  let adjusted = 1.0 -
    (1.0 - r2) * (n - 1.0) / (n - parameter_count.to_double())
  let mse = rss / (n - parameter_count.to_double()).max(1.0)
  let stderr = Array::make(
    coefficients.length(),
    mse.sqrt() / n.sqrt().max(1.0),
  )
  regression_result(
    coefficients~,
    standard_errors=stderr,
    fitted~,
    residuals~,
    r_squared=r2,
    adjusted_r_squared=adjusted,
    residual_sum_squares=rss,
    observations=x.length(),
  )
}

///|
pub fn predict_regression(model : RegressionResult, x : Double) -> Double {
  model.coefficients.foldi(init=0.0, (power, total, coefficient) => {
    total + coefficient * @math.pow(x, power.to_double())
  })
}

///|
pub fn residual_standard_error(model : RegressionResult) -> Double {
  (model.residual_sum_squares /
  (model.observations - model.coefficients.length()).to_double()).sqrt()
}

///|
pub fn durbin_watson(residuals : Array[Double]) -> Double {
  if residuals.length() < 2 {
    abort("Durbin-Watson requires two residuals")
  }
  let mut numerator = 0.0
  for i in 1..<residuals.length() {
    let delta = residuals[i] - residuals[i - 1]
    numerator += delta * delta
  }
  numerator / dot(residuals, residuals)
}

///|
/// A log-log reliability regression where slope is the Weibull shape.
pub fn weibull_probability_plot(
  records : Array[LifeObservation],
) -> RegressionResult {
  let failures = records.filter_map(record => {
    if record.is_failure() {
      Some(record.time)
    } else {
      None
    }
  })
  if failures.length() < 3 {
    abort("probability plot requires three failures")
  }
  failures.sort()
  let x = Array::makei(failures.length(), i => @math.ln(failures[i]))
  let y = Array::makei(failures.length(), i => {
    let p = (i.to_double() + 0.3) / (failures.length().to_double() + 0.4)
    @math.ln(-@math.ln(1.0 - p))
  })
  linear_regression(x, y)
}

///|
pub fn proportional_hazards_score(
  records : Array[LifeObservation],
  covariate : Array[Double],
) -> RegressionResult {
  if records.length() != covariate.length() || records.length() < 3 {
    abort("proportional hazards score requires paired records")
  }
  let y = records.map(record => @math.ln(record.time))
  linear_regression(covariate, y)
}
