///|
/// Failure-mode-and-effects-analysis item.
pub struct RiskItem {
  name : String
  severity : Int
  occurrence : Int
  detection : Int
  risk_priority_number : Int
  recommended_action : String
}

///|
pub fn risk_item(
  name~ : String,
  severity~ : Int,
  occurrence~ : Int,
  detection~ : Int,
  recommended_action~ : String,
) -> RiskItem {
  if severity < 1 ||
    severity > 10 ||
    occurrence < 1 ||
    occurrence > 10 ||
    detection < 1 ||
    detection > 10 {
    abort("FMEA scores must be in 1..10")
  }
  {
    name,
    severity,
    occurrence,
    detection,
    risk_priority_number: severity * occurrence * detection,
    recommended_action,
  }
}

///|
pub fn rank_risks(items : Array[RiskItem]) -> Array[RiskItem] {
  let result = items.copy()
  result.sort_by((left, right) => {
    if left.risk_priority_number > right.risk_priority_number {
      -1
    } else if left.risk_priority_number < right.risk_priority_number {
      1
    } else {
      0
    }
  })
  result
}

///|
pub fn risk_matrix_score(
  severity : Int,
  occurrence : Int,
  detection : Int,
) -> Int {
  severity * occurrence * detection
}

///|
pub fn risk_level(priority_number : Int) -> String {
  if priority_number >= 300 {
    "high"
  } else if priority_number >= 100 {
    "medium"
  } else {
    "low"
  }
}

///|
pub struct FaultTreeResult {
  top_event_probability : Double
  minimal_cut_sets : Array[Array[Int]]
  dominant_component : Int?
}

///|
pub fn fault_tree_result(
  top_event_probability~ : Double,
  minimal_cut_sets~ : Array[Array[Int]],
  dominant_component~ : Int?,
) -> FaultTreeResult {
  { top_event_probability, minimal_cut_sets, dominant_component }
}

///|
pub fn fault_tree_or(events : Array[Double]) -> FaultTreeResult {
  let probability = parallel_reliability(events.map(value => 1.0 - value))
  let cuts = Array::makei(events.length(), i => [i])
  let mut dominant = 0
  for i in 1..<events.length() {
    if events[i] > events[dominant] {
      dominant = i
    }
  }
  fault_tree_result(
    top_event_probability=probability,
    minimal_cut_sets=cuts,
    dominant_component=Some(dominant),
  )
}

///|
pub fn fault_tree_and(events : Array[Double]) -> FaultTreeResult {
  let probability = series_reliability(events)
  let cut : Array[Int] = []
  for i in 0..<events.length() {
    cut.push(i)
  }
  fault_tree_result(
    top_event_probability=probability,
    minimal_cut_sets=[cut],
    dominant_component=None,
  )
}

///|
pub fn minimal_cut_set_probability(
  cut : Array[Int],
  component_failure_probabilities : Array[Double],
) -> Double {
  let mut result = 1.0
  for index in cut {
    result *= component_failure_probabilities[index]
  }
  result
}

///|
pub fn risk_reduction(original : RiskItem, improved_detection : Int) -> Double {
  let new_detection = improved_detection.max(1).min(10)
  1.0 -
  (original.severity * original.occurrence * new_detection).to_double() /
  original.risk_priority_number.to_double()
}

///|
pub fn safety_integrity_level(pfd : Double) -> String {
  if pfd <= 1.0e-5 {
    "SIL4"
  } else if pfd <= 1.0e-4 {
    "SIL3"
  } else if pfd <= 1.0e-3 {
    "SIL2"
  } else if pfd <= 1.0e-2 {
    "SIL1"
  } else {
    "below-SIL"
  }
}
