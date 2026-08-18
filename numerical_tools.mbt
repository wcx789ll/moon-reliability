///|
/// Sum values using a compensated Kahan accumulator.
pub fn compensated_sum(values : Array[Double]) -> Double {
  let mut sum = 0.0
  let mut correction = 0.0
  for value in values {
    let adjusted = value - correction
    let next = sum + adjusted
    correction = next - sum - adjusted
    sum = next
  }
  sum
}

///|
pub fn weighted_sum(values : Array[Double], weights : Array[Double]) -> Double {
  if values.length() != weights.length() {
    abort("values and weights must have the same length")
  }
  let mut result = 0.0
  for i in 0..<values.length() {
    result += values[i] * weights[i]
  }
  result
}

///|
pub fn weighted_mean(values : Array[Double], weights : Array[Double]) -> Double {
  let total = compensated_sum(weights)
  if total <= 0.0 {
    abort("weights must have a positive sum")
  }
  weighted_sum(values, weights) / total
}

///|
pub fn mean(values : Array[Double]) -> Double {
  if values.is_empty() {
    abort("mean requires at least one value")
  }
  compensated_sum(values) / values.length().to_double()
}

///|
pub fn variance(values : Array[Double], unbiased? : Bool = true) -> Double {
  if values.length() < 2 && unbiased {
    abort("unbiased variance requires two values")
  }
  if values.is_empty() {
    abort("variance requires at least one value")
  }
  let center = mean(values)
  let mut sum = 0.0
  for value in values {
    let delta = value - center
    sum += delta * delta
  }
  let divisor = if unbiased { values.length() - 1 } else { values.length() }
  sum / divisor.to_double()
}

///|
pub fn weighted_variance(
  values : Array[Double],
  weights : Array[Double],
) -> Double {
  if values.length() != weights.length() || values.is_empty() {
    abort("values and weights must have the same non-empty length")
  }
  let center = weighted_mean(values, weights)
  let mut numerator = 0.0
  let mut denominator = 0.0
  for i in 0..<values.length() {
    let delta = values[i] - center
    numerator += weights[i] * delta * delta
    denominator += weights[i]
  }
  numerator / denominator
}

///|
pub fn min_value(values : Array[Double]) -> Double {
  if values.is_empty() {
    abort("min requires at least one value")
  }
  let mut result = values[0]
  for value in values[1:] {
    if value < result {
      result = value
    }
  }
  result
}

///|
pub fn max_value(values : Array[Double]) -> Double {
  if values.is_empty() {
    abort("max requires at least one value")
  }
  let mut result = values[0]
  for value in values[1:] {
    if value > result {
      result = value
    }
  }
  result
}

///|
pub fn quantile_sorted(sorted : Array[Double], p : Double) -> Double {
  if sorted.is_empty() {
    abort("quantile requires at least one value")
  }
  if p < 0.0 || p > 1.0 {
    abort("p must be in [0, 1]")
  }
  if sorted.length() == 1 {
    return sorted[0]
  }
  let position = p * (sorted.length() - 1).to_double()
  let lower = position.floor().to_int()
  let upper = position.ceil().to_int()
  let fraction = position - lower.to_double()
  sorted[lower] + fraction * (sorted[upper] - sorted[lower])
}

///|
pub fn quantile(values : Array[Double], p : Double) -> Double {
  let sorted = values.copy()
  sorted.sort()
  quantile_sorted(sorted, p)
}

///|
pub fn percentile_rank(sorted : Array[Double], value : Double) -> Double {
  if sorted.is_empty() {
    abort("percentile rank requires data")
  }
  let mut less = 0
  let mut equal = 0
  for x in sorted {
    if x < value {
      less += 1
    } else if x == value {
      equal += 1
    }
  }
  (less.to_double() + 0.5 * equal.to_double()) / sorted.length().to_double()
}

///|
pub fn dot(left : Array[Double], right : Array[Double]) -> Double {
  if left.length() != right.length() {
    abort("dot product length mismatch")
  }
  let mut result = 0.0
  for i in 0..<left.length() {
    result += left[i] * right[i]
  }
  result
}

///|
pub fn add_vectors(
  left : Array[Double],
  right : Array[Double],
) -> Array[Double] {
  if left.length() != right.length() {
    abort("vector length mismatch")
  }
  Array::makei(left.length(), i => left[i] + right[i])
}

///|
pub fn scale_vector(values : Array[Double], factor : Double) -> Array[Double] {
  values.map(value => value * factor)
}

///|
pub fn linspace(start : Double, stop : Double, count : Int) -> Array[Double] {
  if count <= 0 {
    abort("linspace count must be positive")
  }
  if count == 1 {
    return [start]
  }
  Array::makei(count, i => {
    start + (stop - start) * i.to_double() / (count - 1).to_double()
  })
}

///|
pub fn factorial(n : Int) -> Double {
  if n < 0 {
    abort("factorial requires non-negative n")
  }
  let mut result = 1.0
  for i in 2..<=n {
    result *= i.to_double()
  }
  result
}

///|
pub fn log_factorial(n : Int) -> Double {
  if n < 0 {
    abort("log factorial requires non-negative n")
  }
  let mut result = 0.0
  for i in 2..<=n {
    result += @math.ln(i.to_double())
  }
  result
}

///|
/// Solve a small dense linear system with partial pivoting.
pub fn solve_linear_system(
  matrix : Array[Array[Double]],
  rhs : Array[Double],
) -> Array[Double] {
  let n = rhs.length()
  if matrix.length() != n {
    abort("matrix and rhs dimensions mismatch")
  }
  let a = matrix.map(row => row.copy())
  let b = rhs.copy()
  for pivot in 0..<n {
    let mut best = pivot
    for row in (pivot + 1)..<n {
      if a[row][pivot].abs() > a[best][pivot].abs() {
        best = row
      }
    }
    if a[best][pivot].abs() < 1.0e-14 {
      abort("singular matrix")
    }
    if best != pivot {
      let row = a[pivot]
      a[pivot] = a[best]
      a[best] = row
      let value = b[pivot]
      b[pivot] = b[best]
      b[best] = value
    }
    for row in (pivot + 1)..<n {
      let factor = a[row][pivot] / a[pivot][pivot]
      for col in pivot..<n {
        a[row][col] -= factor * a[pivot][col]
      }
      b[row] -= factor * b[pivot]
    }
  }
  let result = Array::make(n, 0.0)
  for i in 0..<n {
    let row = n - 1 - i
    let mut value = b[row]
    for col in (row + 1)..<n {
      value -= a[row][col] * result[col]
    }
    result[row] = value / a[row][row]
  }
  result
}

///|
pub fn newton_solve(
  initial : Double,
  function : (Double) -> Double,
  derivative : (Double) -> Double,
  lower : Double,
  upper : Double,
  max_iterations : Int,
) -> (Double, Int, Bool) {
  let mut x = initial
  let mut iteration = 0
  let mut converged = false
  while iteration < max_iterations {
    let value = function(x)
    if value.abs() < 1.0e-10 {
      converged = true
      break
    }
    let slope = derivative(x)
    if slope.abs() < 1.0e-14 {
      break
    }
    let next = (x - value / slope).max(lower).min(upper)
    if (next - x).abs() < 1.0e-10 * (1.0 + x.abs()) {
      x = next
      converged = true
      break
    }
    x = next
    iteration += 1
  }
  (x, iteration, converged)
}
