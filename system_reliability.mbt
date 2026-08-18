///|
/// Series, parallel and k-out-of-n block reliability calculations.
pub(all) enum SystemLogic {
  Series
  Parallel
  KOutOfN(Int)
}

///|
pub struct ReliabilitySystem {
  name : String
  logic : SystemLogic
  component_reliabilities : Array[Double]
  reliability : Double
  importance : Array[Double]
}

///|
pub fn reliability_system(
  name~ : String,
  logic~ : SystemLogic,
  component_reliabilities~ : Array[Double],
  reliability~ : Double,
  importance~ : Array[Double],
) -> ReliabilitySystem {
  { name, logic, component_reliabilities, reliability, importance }
}

///|
pub fn series_reliability(components : Array[Double]) -> Double {
  components.fold(init=1.0, (total, value) => total * value)
}

///|
pub fn parallel_reliability(components : Array[Double]) -> Double {
  1.0 - components.fold(init=1.0, (total, value) => total * (1.0 - value))
}

///|
pub fn k_out_of_n_reliability(
  k : Int,
  component_reliability : Double,
  n : Int,
) -> Double {
  if k <= 0 {
    return 1.0
  }
  if k > n {
    return 0.0
  }
  let mut result = 0.0
  for successes in k..<=n {
    result += choose(n, successes) *
      @math.pow(component_reliability, successes.to_double()) *
      @math.pow(1.0 - component_reliability, (n - successes).to_double())
  }
  result
}

///|
pub fn k_out_of_n_components(k : Int, components : Array[Double]) -> Double {
  if k <= 0 {
    return 1.0
  }
  if k > components.length() {
    return 0.0
  }
  let mut probability = 0.0
  let mut states = 1
  for _ in 0..<components.length() {
    states *= 2
  }
  for mask in 0..<states {
    let mut successes = 0
    let mut state_probability = 1.0
    for i in 0..<components.length() {
      let on = mask / (2 ^ i) % 2 == 1
      if on {
        successes += 1
        state_probability *= components[i]
      } else {
        state_probability *= 1.0 - components[i]
      }
    }
    if successes >= k {
      probability += state_probability
    }
  }
  probability
}

///|
pub fn SystemLogic::evaluate(
  self : SystemLogic,
  components : Array[Double],
) -> Double {
  match self {
    Series => series_reliability(components)
    Parallel => parallel_reliability(components)
    KOutOfN(k) => k_out_of_n_components(k, components)
  }
}

///|
pub fn build_reliability_system(
  name : String,
  logic : SystemLogic,
  components : Array[Double],
) -> ReliabilitySystem {
  let value = logic.evaluate(components)
  let importance = component_importance(logic, components)
  reliability_system(
    name~,
    logic~,
    component_reliabilities=components.copy(),
    reliability=value,
    importance~,
  )
}

///|
pub fn component_importance(
  logic : SystemLogic,
  components : Array[Double],
) -> Array[Double] {
  Array::makei(components.length(), i => {
    let degraded = components.copy()
    degraded[i] = 0.0
    logic.evaluate(components) - logic.evaluate(degraded)
  })
}

///|
pub fn series_hazard(models : Array[ReliabilityModel], time : Double) -> Double {
  models.fold(init=0.0, (total, model) => total + model_hazard(model, time))
}

///|
pub fn parallel_hazard(
  models : Array[ReliabilityModel],
  time : Double,
) -> Double {
  let survival = models.fold(init=1.0, (total, model) => {
    total * model.survival(time)
  })
  let mut numerator = 0.0
  for model in models {
    numerator += model_hazard(model, time) * model.survival(time)
  }
  if survival <= 1.0e-300 {
    1.0e300
  } else {
    numerator / survival
  }
}

///|
pub fn repairable_availability(
  failure_rate : Double,
  repair_rate : Double,
) -> Double {
  if failure_rate < 0.0 || repair_rate <= 0.0 {
    abort("invalid repairable rates")
  }
  repair_rate / (failure_rate + repair_rate)
}

///|
pub fn steady_state_unavailability(
  failure_rate : Double,
  repair_rate : Double,
) -> Double {
  1.0 - repairable_availability(failure_rate, repair_rate)
}

///|
pub fn common_cause_adjustment(independent : Double, beta : Double) -> Double {
  if beta < 0.0 || beta > 1.0 {
    abort("beta must be in [0, 1]")
  }
  independent * (1.0 - beta)
}

///|
pub fn choose(n : Int, k : Int) -> Double {
  if k < 0 || k > n {
    return 0.0
  }
  let reduced = k.min(n - k)
  let mut result = 1.0
  for i in 1..<=reduced {
    result *= (n - reduced + i).to_double() / i.to_double()
  }
  result
}
