///|
/// A component target used in reliability allocation studies.
pub struct AllocationComponent {
  component_id : Int
  name : String
  current_reliability : Double
  target_reliability : Double
  cost : Double
  weight : Double
  failure_rate : Double
  repair_time : Double
}

///|
pub fn allocation_component(
  component_id : Int,
  name : String,
  current_reliability : Double,
  target_reliability : Double,
  cost : Double,
  weight : Double,
  failure_rate : Double,
  repair_time : Double,
) -> AllocationComponent {
  if component_id < 0 ||
    current_reliability <= 0.0 ||
    current_reliability > 1.0 ||
    target_reliability <= 0.0 ||
    target_reliability > 1.0 ||
    cost < 0.0 ||
    weight <= 0.0 ||
    failure_rate < 0.0 ||
    repair_time < 0.0 {
    abort("invalid allocation component")
  }
  {
    component_id,
    name,
    current_reliability,
    target_reliability,
    cost,
    weight,
    failure_rate,
    repair_time,
  }
}

///|
pub fn allocation_gap(component : AllocationComponent) -> Double {
  component.target_reliability - component.current_reliability
}

///|
pub fn allocation_failure_probability(
  component : AllocationComponent,
) -> Double {
  1.0 - component.current_reliability
}

///|
pub fn allocation_target_failure_probability(
  component : AllocationComponent,
) -> Double {
  1.0 - component.target_reliability
}

///|
pub fn allocation_improvement_needed(component : AllocationComponent) -> Double {
  allocation_gap(component).max(0.0)
}

///|
pub fn allocation_cost_per_reliability(
  component : AllocationComponent,
) -> Double {
  allocation_improvement_needed(component) / component.cost.max(1.0e-12)
}

///|
pub fn allocation_risk_priority(component : AllocationComponent) -> Double {
  allocation_failure_probability(component) *
  component.weight *
  (1.0 + component.failure_rate * component.repair_time)
}

///|
pub fn allocation_criticality(component : AllocationComponent) -> Double {
  component.weight * allocation_failure_probability(component)
}

///|
pub struct ReliabilityAllocationPlan {
  components : Array[AllocationComponent]
  system_target : Double
  architecture : String
  budget : Double
  system_reliability : Double
  total_cost : Double
  total_risk : Double
  feasible : Bool
}

///|
pub fn reliability_allocation_plan(
  components : Array[AllocationComponent],
  system_target : Double,
  architecture : String,
  budget : Double,
) -> ReliabilityAllocationPlan {
  if components.is_empty() ||
    system_target <= 0.0 ||
    system_target > 1.0 ||
    budget < 0.0 {
    abort("invalid allocation plan")
  }
  let reliability = if architecture == "series" {
    components.fold(init=1.0, (product, component) => {
      product * component.target_reliability
    })
  } else if architecture == "parallel" {
    let failure = components.fold(init=1.0, (product, component) => {
      product * (1.0 - component.target_reliability)
    })
    1.0 - failure
  } else {
    abort("architecture must be series or parallel")
  }
  let total_cost = components.fold(init=0.0, (total, component) => {
    total + component.cost
  })
  let total_risk = components.fold(init=0.0, (total, component) => {
    total + allocation_risk_priority(component)
  })
  {
    components,
    system_target,
    architecture,
    budget,
    system_reliability: reliability,
    total_cost,
    total_risk,
    feasible: reliability >= system_target && total_cost <= budget,
  }
}

///|
pub fn allocation_system_reliability(
  plan : ReliabilityAllocationPlan,
) -> Double {
  plan.system_reliability
}

///|
pub fn allocation_system_margin(plan : ReliabilityAllocationPlan) -> Double {
  plan.system_reliability - plan.system_target
}

///|
pub fn allocation_budget_remaining(plan : ReliabilityAllocationPlan) -> Double {
  plan.budget - plan.total_cost
}

///|
pub fn allocation_is_feasible(plan : ReliabilityAllocationPlan) -> Bool {
  plan.feasible
}

///|
pub fn allocation_component_count(plan : ReliabilityAllocationPlan) -> Int {
  plan.components.length()
}

///|
pub fn allocation_series_target(
  system_target : Double,
  component_count : Int,
) -> Double {
  if system_target <= 0.0 || system_target > 1.0 || component_count < 1 {
    abort("invalid series allocation inputs")
  }
  @math.pow(system_target, 1.0 / component_count.to_double())
}

///|
pub fn allocation_series_targets(
  system_target : Double,
  component_count : Int,
) -> Array[Double] {
  Array::make(
    component_count,
    allocation_series_target(system_target, component_count),
  )
}

///|
pub fn allocation_parallel_target(
  system_target : Double,
  component_count : Int,
) -> Double {
  if system_target <= 0.0 || system_target > 1.0 || component_count < 1 {
    abort("invalid parallel allocation inputs")
  }
  1.0 - @math.pow(1.0 - system_target, 1.0 / component_count.to_double())
}

///|
pub fn allocation_parallel_targets(
  system_target : Double,
  component_count : Int,
) -> Array[Double] {
  Array::make(
    component_count,
    allocation_parallel_target(system_target, component_count),
  )
}

///|
pub fn allocation_series_reliability(reliabilities : Array[Double]) -> Double {
  if reliabilities.is_empty() {
    abort("series requires components")
  }
  reliabilities.fold(init=1.0, (product, value) => {
    product * value.max(0.0).min(1.0)
  })
}

///|
pub fn allocation_parallel_reliability(reliabilities : Array[Double]) -> Double {
  if reliabilities.is_empty() {
    abort("parallel requires components")
  }
  1.0 -
  reliabilities.fold(init=1.0, (product, value) => {
    product * (1.0 - value.max(0.0).min(1.0))
  })
}

///|
pub fn allocation_k_out_of_n_reliability(
  reliability : Double,
  count : Int,
  required : Int,
) -> Double {
  if reliability < 0.0 ||
    reliability > 1.0 ||
    count < 1 ||
    required < 1 ||
    required > count {
    abort("invalid k-out-of-n inputs")
  }
  let mut result = 0.0
  for successes in required..<=count {
    result += @math.exp(
      log_factorial(count) -
      log_factorial(successes) -
      log_factorial(count - successes) +
      successes.to_double() * safe_log_probability(reliability) +
      (count - successes).to_double() * safe_log_probability(1.0 - reliability),
    )
  }
  result.min(1.0).max(0.0)
}

///|
pub fn allocation_k_out_of_n_failure(
  reliability : Double,
  count : Int,
  required : Int,
) -> Double {
  1.0 - allocation_k_out_of_n_reliability(reliability, count, required)
}

///|
pub fn allocation_redundancy_gain(
  reliability : Double,
  added_units : Int,
) -> Double {
  if added_units < 0 {
    abort("added units must be non-negative")
  }
  allocation_parallel_reliability(Array::make(added_units + 1, reliability)) -
  reliability
}

///|
pub fn allocation_redundancy_count(
  target : Double,
  component_reliability : Double,
  maximum_units : Int,
) -> Int {
  if target <= 0.0 ||
    target > 1.0 ||
    component_reliability <= 0.0 ||
    component_reliability > 1.0 ||
    maximum_units < 1 {
    abort("invalid redundancy inputs")
  }
  for units in 1..<=maximum_units {
    if allocation_parallel_reliability(
        Array::make(units, component_reliability),
      ) >=
      target {
      return units
    }
  }
  maximum_units
}

///|
pub fn allocation_redundancy_cost(
  target : Double,
  component_reliability : Double,
  unit_cost : Double,
  maximum_units : Int,
) -> Double {
  if unit_cost < 0.0 {
    abort("unit cost must be non-negative")
  }
  allocation_redundancy_count(target, component_reliability, maximum_units).to_double() *
  unit_cost
}

///|
pub fn allocation_marginal_reliability(
  reliabilities : Array[Double],
  component_index : Int,
  architecture : String,
) -> Double {
  if component_index < 0 || component_index >= reliabilities.length() {
    abort("component index out of range")
  }
  let baseline = if architecture == "series" {
    allocation_series_reliability(reliabilities)
  } else {
    allocation_parallel_reliability(reliabilities)
  }
  let improved = reliabilities.copy()
  improved[component_index] = (improved[component_index] + 1.0e-5).min(1.0)
  let next = if architecture == "series" {
    allocation_series_reliability(improved)
  } else {
    allocation_parallel_reliability(improved)
  }
  (next - baseline) / 1.0e-5
}

///|
pub fn allocation_importance_factors(
  reliabilities : Array[Double],
  architecture : String,
) -> Array[Double] {
  Array::makei(reliabilities.length(), i => {
    allocation_marginal_reliability(reliabilities, i, architecture)
  })
}

///|
pub fn allocation_importance_rank(
  reliabilities : Array[Double],
  architecture : String,
) -> Array[Int] {
  let indices = Array::makei(reliabilities.length(), i => i)
  indices.sort_by((left, right) => {
    let left_value = allocation_marginal_reliability(
      reliabilities, left, architecture,
    )
    let right_value = allocation_marginal_reliability(
      reliabilities, right, architecture,
    )
    if left_value > right_value {
      -1
    } else if left_value < right_value {
      1
    } else {
      0
    }
  })
  indices
}

///|
pub fn allocation_risk_rank(
  components : Array[AllocationComponent],
) -> Array[AllocationComponent] {
  let result = components.copy()
  result.sort_by((left, right) => {
    let left_risk = allocation_risk_priority(left)
    let right_risk = allocation_risk_priority(right)
    if left_risk > right_risk {
      -1
    } else if left_risk < right_risk {
      1
    } else {
      0
    }
  })
  result
}

///|
pub fn allocation_cost_rank(
  components : Array[AllocationComponent],
) -> Array[AllocationComponent] {
  let result = components.copy()
  result.sort_by((left, right) => {
    let left_value = allocation_cost_per_reliability(left)
    let right_value = allocation_cost_per_reliability(right)
    if left_value > right_value {
      -1
    } else if left_value < right_value {
      1
    } else {
      0
    }
  })
  result
}

///|
pub fn allocation_priority_scores(
  components : Array[AllocationComponent],
) -> Array[Double] {
  components.map(component => {
    allocation_risk_priority(component) +
    allocation_improvement_needed(component)
  })
}

///|
pub fn allocation_total_improvement(
  components : Array[AllocationComponent],
) -> Double {
  components.fold(init=0.0, (total, component) => {
    total + allocation_improvement_needed(component)
  })
}

///|
pub fn allocation_total_cost(components : Array[AllocationComponent]) -> Double {
  components.fold(init=0.0, (total, component) => total + component.cost)
}

///|
pub fn allocation_total_risk(components : Array[AllocationComponent]) -> Double {
  components.fold(init=0.0, (total, component) => {
    total + allocation_risk_priority(component)
  })
}

///|
pub fn allocation_budget_select(
  components : Array[AllocationComponent],
  budget : Double,
) -> Array[AllocationComponent] {
  if budget < 0.0 {
    abort("budget must be non-negative")
  }
  let result = []
  let mut remaining = budget
  let ranked = allocation_risk_rank(components)
  for component in ranked {
    if component.cost <= remaining {
      result.push(component)
      remaining -= component.cost
    }
  }
  result
}

///|
pub fn allocation_selection_budget_remaining(
  components : Array[AllocationComponent],
  budget : Double,
) -> Double {
  budget - allocation_total_cost(allocation_budget_select(components, budget))
}

///|
pub fn allocation_budget_utilization(
  components : Array[AllocationComponent],
  budget : Double,
) -> Double {
  if budget <= 0.0 {
    abort("budget must be positive")
  }
  allocation_total_cost(allocation_budget_select(components, budget)) / budget
}

///|
pub fn allocation_system_target_met(
  reliabilities : Array[Double],
  system_target : Double,
  architecture : String,
) -> Bool {
  let actual = if architecture == "series" {
    allocation_series_reliability(reliabilities)
  } else {
    allocation_parallel_reliability(reliabilities)
  }
  actual >= system_target
}

///|
pub fn allocation_target_adjustment(
  reliabilities : Array[Double],
  system_target : Double,
  architecture : String,
) -> Array[Double] {
  if architecture == "series" {
    let target = allocation_series_target(system_target, reliabilities.length())
    reliabilities.map(value => (target - value).max(0.0))
  } else {
    let target = allocation_parallel_target(
      system_target,
      reliabilities.length(),
    )
    reliabilities.map(value => (target - value).max(0.0))
  }
}

///|
pub fn allocation_target_sensitivity(
  reliabilities : Array[Double],
  system_target : Double,
  architecture : String,
) -> Array[Double] {
  let adjustments = allocation_target_adjustment(
    reliabilities, system_target, architecture,
  )
  let total = adjustments.fold(init=0.0, (sum, value) => sum + value)
  if total == 0.0 {
    adjustments.map(_ => 0.0)
  } else {
    adjustments.map(value => value / total)
  }
}

///|
pub fn allocation_reliability_checksum(
  components : Array[AllocationComponent],
) -> Double {
  components.fold(init=0.0, (total, component) => {
    total +
    component.component_id.to_double() +
    component.current_reliability +
    component.target_reliability +
    component.cost +
    component.weight +
    component.failure_rate +
    component.repair_time
  })
}

///|
pub struct AllocationScenario {
  name : String
  reliability : Double
  cost : Double
  risk : Double
  score : Double
}

///|
pub fn allocation_scenario(
  name : String,
  reliability : Double,
  cost : Double,
  risk : Double,
  score : Double,
) -> AllocationScenario {
  { name, reliability, cost, risk, score }
}

///|
pub fn allocation_scenario_score(scenario : AllocationScenario) -> Double {
  scenario.score
}

///|
pub fn allocation_scenario_rank(
  scenarios : Array[AllocationScenario],
) -> Array[AllocationScenario] {
  let result = scenarios.copy()
  result.sort_by((left, right) => {
    if left.score > right.score {
      -1
    } else if left.score < right.score {
      1
    } else {
      0
    }
  })
  result
}

///|
pub fn allocation_best_scenario(
  scenarios : Array[AllocationScenario],
) -> AllocationScenario {
  allocation_scenario_rank(scenarios)[0]
}

///|
pub fn allocation_scenario_feasible(
  scenario : AllocationScenario,
  target : Double,
  budget : Double,
) -> Bool {
  scenario.reliability >= target && scenario.cost <= budget
}

///|
pub fn allocation_scenario_filter(
  scenarios : Array[AllocationScenario],
  target : Double,
  budget : Double,
) -> Array[AllocationScenario] {
  scenarios.filter(scenario => {
    allocation_scenario_feasible(scenario, target, budget)
  })
}

///|
pub fn allocation_scenario_checksum(
  scenarios : Array[AllocationScenario],
) -> Double {
  scenarios.fold(init=0.0, (total, scenario) => {
    total +
    scenario.reliability +
    scenario.cost +
    scenario.risk +
    scenario.score
  })
}

///|
pub fn allocation_series_failure_rate(
  rates : Array[Double],
  mission_time : Double,
) -> Double {
  if mission_time < 0.0 {
    abort("mission time must be non-negative")
  }
  1.0 -
  @math.exp(
    -rates.fold(init=0.0, (total, value) => total + value.max(0.0)) *
    mission_time,
  )
}

///|
pub fn allocation_parallel_failure_rate(
  rates : Array[Double],
  mission_time : Double,
) -> Double {
  if mission_time < 0.0 {
    abort("mission time must be non-negative")
  }
  rates.fold(init=1.0, (survival, rate) => {
    survival * (1.0 - (1.0 - @math.exp(-rate.max(0.0) * mission_time)))
  })
}

///|
pub fn allocation_series_availability(availability : Array[Double]) -> Double {
  allocation_series_reliability(availability)
}

///|
pub fn allocation_parallel_availability(availability : Array[Double]) -> Double {
  allocation_parallel_reliability(availability)
}

///|
pub fn allocation_redundancy_availability(
  component_availability : Double,
  component_count : Int,
  required : Int,
) -> Double {
  allocation_k_out_of_n_reliability(
    component_availability, component_count, required,
  )
}

///|
pub fn allocation_repairable_series_availability(
  failure_rates : Array[Double],
  repair_rates : Array[Double],
) -> Double {
  if failure_rates.length() != repair_rates.length() || failure_rates.is_empty() {
    abort("rate vectors must have same non-empty length")
  }
  allocation_series_availability(
    Array::makei(failure_rates.length(), i => {
      let failure = failure_rates[i].max(0.0)
      let repair = repair_rates[i].max(0.0)
      if failure + repair == 0.0 {
        1.0
      } else {
        repair / (failure + repair)
      }
    }),
  )
}

///|
pub fn allocation_repairable_parallel_availability(
  failure_rates : Array[Double],
  repair_rates : Array[Double],
) -> Double {
  if failure_rates.length() != repair_rates.length() || failure_rates.is_empty() {
    abort("rate vectors must have same non-empty length")
  }
  allocation_parallel_availability(
    Array::makei(failure_rates.length(), i => {
      let failure = failure_rates[i].max(0.0)
      let repair = repair_rates[i].max(0.0)
      if failure + repair == 0.0 {
        1.0
      } else {
        repair / (failure + repair)
      }
    }),
  )
}

///|
pub fn allocation_component_contribution(
  component : AllocationComponent,
  architecture : String,
) -> Double {
  if architecture == "series" {
    component.current_reliability
  } else {
    1.0 - component.current_reliability
  }
}

///|
pub fn allocation_component_target_contribution(
  component : AllocationComponent,
  architecture : String,
) -> Double {
  if architecture == "series" {
    component.target_reliability
  } else {
    1.0 - component.target_reliability
  }
}

///|
pub fn allocation_component_delta_score(
  component : AllocationComponent,
  architecture : String,
) -> Double {
  (allocation_component_target_contribution(component, architecture) -
  allocation_component_contribution(component, architecture)).abs() *
  component.weight
}

///|
pub fn allocation_delta_scores(
  components : Array[AllocationComponent],
  architecture : String,
) -> Array[Double] {
  components.map(component => {
    allocation_component_delta_score(component, architecture)
  })
}

///|
pub fn allocation_delta_rank(
  components : Array[AllocationComponent],
  architecture : String,
) -> Array[AllocationComponent] {
  let result = components.copy()
  result.sort_by((left, right) => {
    let left_score = allocation_component_delta_score(left, architecture)
    let right_score = allocation_component_delta_score(right, architecture)
    if left_score > right_score {
      -1
    } else if left_score < right_score {
      1
    } else {
      0
    }
  })
  result
}
