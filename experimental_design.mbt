///|
/// A stress-test design point.
pub struct DesignPoint {
  id : Int
  factors : Array[Double]
  replicate : Int
  center : Bool
}

///|
pub fn design_point(
  id~ : Int,
  factors~ : Array[Double],
  replicate~ : Int,
  center~ : Bool,
) -> DesignPoint {
  { id, factors, replicate, center }
}

///|
pub fn full_factorial(levels : Array[Array[Double]]) -> Array[DesignPoint] {
  if levels.is_empty() {
    abort("factorial design needs factors")
  }
  let result : Array[DesignPoint] = []
  fn expand(index : Int, current : Array[Double]) -> Unit {
    if index == levels.length() {
      result.push(
        design_point(
          id=result.length() + 1,
          factors=current.copy(),
          replicate=1,
          center=false,
        ),
      )
    } else {
      for value in levels[index] {
        current.push(value)
        expand(index + 1, current)
        ignore(current.pop())
      }
    }
  }
  expand(0, [])
  result
}

///|
pub fn central_composite_design(
  factor_count : Int,
  axial_distance : Double,
) -> Array[DesignPoint] {
  if factor_count <= 0 {
    abort("factor count must be positive")
  }
  let levels = Array::makei(factor_count, _ => [-1.0, 1.0])
  let result = full_factorial(levels)
  for i in 0..<factor_count {
    let plus = Array::make(factor_count, 0.0)
    plus[i] = axial_distance
    let minus = Array::make(factor_count, 0.0)
    minus[i] = -axial_distance
    result.push(
      design_point(
        id=result.length() + 1,
        factors=plus,
        replicate=1,
        center=false,
      ),
    )
    result.push(
      design_point(
        id=result.length() + 1,
        factors=minus,
        replicate=1,
        center=false,
      ),
    )
  }
  result.push(
    design_point(
      id=result.length() + 1,
      factors=Array::make(factor_count, 0.0),
      replicate=3,
      center=true,
    ),
  )
  result
}

///|
pub fn latin_hypercube(
  seed : Int,
  runs : Int,
  factors : Int,
) -> Array[DesignPoint] {
  if runs <= 0 || factors <= 0 {
    abort("invalid Latin-hypercube dimensions")
  }
  let state = RandomState::new(seed)
  let result = Array::makei(runs, i => {
    design_point(
      id=i + 1,
      factors=Array::make(factors, 0.0),
      replicate=1,
      center=false,
    )
  })
  for factor in 0..<factors {
    let bins = Array::makei(runs, i => {
      (i.to_double() + state.uniform()) / runs.to_double()
    })
    bins.shuffle_in_place(rand=limit => state.next_int().abs() % limit)
    for i in 0..<runs {
      result[i].factors[factor] = bins[i]
    }
  }
  result
}

///|
pub fn replicate_design(
  design : Array[DesignPoint],
  replicates : Int,
) -> Array[DesignPoint] {
  if replicates <= 0 {
    abort("replicates must be positive")
  }
  let result : Array[DesignPoint] = []
  for point in design {
    for replicate in 1..<=replicates {
      result.push(
        design_point(
          id=result.length() + 1,
          factors=point.factors.copy(),
          replicate~,
          center=point.center,
        ),
      )
    }
  }
  result
}

///|
pub fn code_factor(value : Double, lower : Double, upper : Double) -> Double {
  if upper <= lower {
    abort("factor bounds must increase")
  }
  2.0 * (value - lower) / (upper - lower) - 1.0
}

///|
pub fn decode_factor(code : Double, lower : Double, upper : Double) -> Double {
  lower + (code + 1.0) * (upper - lower) / 2.0
}

///|
pub fn design_correlation(
  design : Array[DesignPoint],
  first_factor : Int,
  second_factor : Int,
) -> Double {
  let left = design.map(point => point.factors[first_factor])
  let right = design.map(point => point.factors[second_factor])
  correlation(left, right)
}
