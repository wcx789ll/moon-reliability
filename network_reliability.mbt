///|
/// A small path-set network model. Paths use zero-based component indexes.
pub struct NetworkReliability {
  component_count : Int
  paths : Array[Array[Int]]
  reliability : Double
  path_contributions : Array[Double]
}

///|
pub fn network_reliability(
  component_count~ : Int,
  paths~ : Array[Array[Int]],
  reliability~ : Double,
  path_contributions~ : Array[Double],
) -> NetworkReliability {
  { component_count, paths, reliability, path_contributions }
}

///|
pub fn path_reliability(
  path : Array[Int],
  components : Array[Double],
) -> Double {
  let mut result = 1.0
  for component in path {
    result *= components[component]
  }
  result
}

///|
pub fn network_reliability_from_paths(
  component_count : Int,
  paths : Array[Array[Int]],
  components : Array[Double],
) -> NetworkReliability {
  if components.length() != component_count || paths.is_empty() {
    abort("invalid network dimensions")
  }
  let contributions = paths.map(path => path_reliability(path, components))
  let mut reliability = 0.0
  for contribution in contributions {
    reliability += contribution
  }
  reliability = reliability.min(1.0)
  network_reliability(
    component_count~,
    paths~,
    reliability~,
    path_contributions=contributions,
  )
}

///|
pub fn network_component_importance(
  network : NetworkReliability,
  components : Array[Double],
) -> Array[Double] {
  if components.length() != network.component_count {
    abort("component count mismatch")
  }
  Array::makei(network.component_count, component => {
    let mut contribution = 0.0
    for i in 0..<network.paths.length() {
      if network.paths[i].contains(component) {
        contribution += network.path_contributions[i]
      }
    }
    contribution
  })
}

///|
pub fn network_min_cut(paths : Array[Array[Int]]) -> Array[Array[Int]] {
  let result : Array[Array[Int]] = []
  for path in paths {
    result.push(path.copy())
  }
  result.sort_by((left, right) => {
    if left.length() < right.length() {
      -1
    } else if left.length() > right.length() {
      1
    } else {
      0
    }
  })
  result
}

///|
pub fn bridge_component_reliability(
  left : Double,
  bridge : Double,
  right : Double,
) -> Double {
  let series = left * bridge * right
  let bypass = left * right
  (series + bypass - series * bypass).min(1.0)
}

///|
pub fn network_failure_probability(network : NetworkReliability) -> Double {
  1.0 - network.reliability
}

///|
pub fn network_redundancy_gain(
  base : NetworkReliability,
  redundant : NetworkReliability,
) -> Double {
  redundant.reliability - base.reliability
}
