///|
/// Maintenance policy for preventive and corrective actions.
pub(all) enum MaintenanceAction {
  Inspect
  PreventiveReplace
  CorrectiveRepair
  NoAction
} derive(Debug, Eq)

///|
pub struct MaintenanceSchedule {
  ages : Array[Double]
  actions : Array[MaintenanceAction]
  expected_costs : Array[Double]
  expected_availability : Array[Double]
  selected_age : Double
}

///|
pub fn maintenance_schedule(
  ages~ : Array[Double],
  actions~ : Array[MaintenanceAction],
  expected_costs~ : Array[Double],
  expected_availability~ : Array[Double],
  selected_age~ : Double,
) -> MaintenanceSchedule {
  { ages, actions, expected_costs, expected_availability, selected_age }
}

///|
pub fn age_replacement_schedule(
  model : ReliabilityModel,
  policy_cost : Double,
  repair_cost : Double,
  start_age : Double,
  end_age : Double,
  steps : Int,
) -> MaintenanceSchedule {
  let ages = linspace(start_age, end_age, steps)
  let costs = ages.map(age => {
    let failure_probability = model.cdf(age)
    policy_cost / age + repair_cost * failure_probability / age
  })
  let availability = ages.map(age => model.survival(age))
  let mut best = 0
  for i in 1..<ages.length() {
    if costs[i] < costs[best] {
      best = i
    }
  }
  let actions = Array::make(ages.length(), PreventiveReplace)
  maintenance_schedule(
    ages~,
    actions~,
    expected_costs=costs,
    expected_availability=availability,
    selected_age=ages[best],
  )
}

///|
pub fn inspection_interval(
  model : ReliabilityModel,
  target_availability : Double,
  cost_of_inspection : Double,
  cost_of_failure : Double,
) -> Double {
  let mut best_interval = 1.0
  let mut best_cost = 1.0e300
  for interval in linspace(0.1, 100.0, 200) {
    let availability = model.survival(interval)
    if availability >= target_availability {
      let cost = cost_of_inspection / interval +
        cost_of_failure * (1.0 - availability) / interval
      if cost < best_cost {
        best_cost = cost
        best_interval = interval
      }
    }
  }
  best_interval
}

///|
pub fn renewal_reward_rate(
  model : ReliabilityModel,
  replacement_cost : Double,
  reward_per_time : Double,
  age : Double,
) -> Double {
  if age <= 0.0 {
    abort("renewal age must be positive")
  }
  let survival = model.survival(age)
  let expected_cycle = age * survival + model_mean(model) * (1.0 - survival)
  (reward_per_time * expected_cycle - replacement_cost) / expected_cycle
}

///|
pub fn optimum_renewal_age(
  model : ReliabilityModel,
  replacement_cost : Double,
  reward_per_time : Double,
  start : Double,
  stop : Double,
  steps : Int,
) -> Double {
  let ages = linspace(start, stop, steps)
  let rates = ages.map(age => {
    renewal_reward_rate(model, replacement_cost, reward_per_time, age)
  })
  let mut best = 0
  for i in 1..<ages.length() {
    if rates[i] > rates[best] {
      best = i
    }
  }
  ages[best]
}

///|
pub fn repair_queue_utilization(
  arrival_rate : Double,
  service_rate : Double,
) -> Double {
  if arrival_rate < 0.0 || service_rate <= 0.0 || arrival_rate >= service_rate {
    1.0
  } else {
    arrival_rate / service_rate
  }
}

///|
pub fn expected_repair_queue_length(
  arrival_rate : Double,
  service_rate : Double,
) -> Double {
  let utilization = repair_queue_utilization(arrival_rate, service_rate)
  if utilization >= 1.0 {
    1.0e300
  } else {
    utilization * utilization / (1.0 - utilization)
  }
}
