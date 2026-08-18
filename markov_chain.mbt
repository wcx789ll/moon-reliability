///|
/// Finite-state transition matrix for repairable systems.
pub struct TransitionMatrix {
  states : Int
  values : Array[Array[Double]]
}

///|
pub fn transition_matrix(values : Array[Array[Double]]) -> TransitionMatrix {
  if values.is_empty() {
    abort("transition matrix cannot be empty")
  }
  let states = values.length()
  for row in values {
    if row.length() != states {
      abort("transition matrix must be square")
    }
    let total = row.fold(init=0.0, (sum, value) => sum + value)
    if total < 0.999999 || total > 1.000001 {
      abort("transition rows must sum to one")
    }
  }
  { states, values: values.map(row => row.copy()) }
}

///|
pub fn TransitionMatrix::step(
  self : TransitionMatrix,
  distribution : Array[Double],
) -> Array[Double] {
  if distribution.length() != self.states {
    abort("distribution dimension mismatch")
  }
  Array::makei(self.states, destination => {
    let mut result = 0.0
    for source in 0..<self.states {
      result += distribution[source] * self.values[source][destination]
    }
    result
  })
}

///|
pub fn TransitionMatrix::power(
  self : TransitionMatrix,
  distribution : Array[Double],
  steps : Int,
) -> Array[Double] {
  let mut result = distribution.copy()
  for _ in 0..<steps {
    result = self.step(result)
  }
  result
}

///|
pub fn steady_state_distribution(
  matrix : TransitionMatrix,
  tolerance : Double,
  max_iterations : Int,
) -> Array[Double] {
  let mut distribution = Array::make(
    matrix.states,
    1.0 / matrix.states.to_double(),
  )
  let mut iteration = 0
  while iteration < max_iterations {
    let next = matrix.step(distribution)
    let difference = next.foldi(init=0.0, (i, total, value) => {
      total + (value - distribution[i]).abs()
    })
    distribution = next
    iteration += 1
    if difference < tolerance {
      break
    }
  }
  distribution
}

///|
pub fn two_state_transition(
  failure_rate : Double,
  repair_rate : Double,
  step : Double,
) -> TransitionMatrix {
  let failure_probability = 1.0 - @math.exp(-failure_rate * step)
  let repair_probability = 1.0 - @math.exp(-repair_rate * step)
  transition_matrix([
    [1.0 - failure_probability, failure_probability],
    [repair_probability, 1.0 - repair_probability],
  ])
}

///|
pub fn state_occupancy(
  matrix : TransitionMatrix,
  initial_state : Int,
  horizon : Double,
  step : Double,
) -> Array[Double] {
  if initial_state < 0 || initial_state >= matrix.states || step <= 0.0 {
    abort("invalid state occupancy inputs")
  }
  let count = (horizon / step).ceil().to_int() + 1
  let distribution = Array::make(matrix.states, 0.0)
  distribution[initial_state] = 1.0
  let result : Array[Double] = []
  let mut current = distribution
  for _ in 0..<count {
    result.push(current[0])
    current = matrix.step(current)
  }
  result
}

///|
pub fn expected_state_time(
  matrix : TransitionMatrix,
  initial_state : Int,
  horizon : Double,
  step : Double,
  target_state : Int,
) -> Double {
  if target_state < 0 || target_state >= matrix.states {
    abort("target state outside matrix")
  }
  ignore(target_state)
  let occupancy = state_occupancy(matrix, initial_state, horizon, step)
  occupancy
  .fold(init=0.0, (sum, probability) => sum + probability * step)
  .max(0.0)
}
