///|
/// Warranty policy and renewal-cost analysis.
pub struct WarrantyPolicy {
  duration : Double
  replacement_cost : Double
  service_cost : Double
  salvage_value : Double
  renewal : Bool
}

///|
pub fn warranty_policy(
  duration~ : Double,
  replacement_cost~ : Double,
  service_cost~ : Double,
  salvage_value~ : Double,
  renewal~ : Bool,
) -> WarrantyPolicy {
  if duration <= 0.0 || replacement_cost < 0.0 || service_cost < 0.0 {
    abort("invalid warranty policy")
  }
  { duration, replacement_cost, service_cost, salvage_value, renewal }
}

///|
pub struct WarrantyAnalysis {
  claims : Double
  expected_cost : Double
  cost_per_unit_time : Double
  claim_probability : Double
  renewal_cycles : Double
}

///|
pub fn warranty_analysis(
  claims~ : Double,
  expected_cost~ : Double,
  cost_per_unit_time~ : Double,
  claim_probability~ : Double,
  renewal_cycles~ : Double,
) -> WarrantyAnalysis {
  {
    claims,
    expected_cost,
    cost_per_unit_time,
    claim_probability,
    renewal_cycles,
  }
}

///|
pub fn expected_warranty_claims(
  model : ReliabilityModel,
  policy : WarrantyPolicy,
) -> Double {
  model.cdf(policy.duration)
}

///|
pub fn expected_warranty_cost(
  model : ReliabilityModel,
  policy : WarrantyPolicy,
) -> Double {
  expected_warranty_claims(model, policy) *
  (policy.replacement_cost + policy.service_cost) -
  policy.salvage_value * model.survival(policy.duration)
}

///|
pub fn analyze_warranty(
  model : ReliabilityModel,
  policy : WarrantyPolicy,
) -> WarrantyAnalysis {
  let claim_probability = expected_warranty_claims(model, policy)
  let cost = expected_warranty_cost(model, policy)
  let cycles = if policy.renewal {
    1.0 / model.survival(policy.duration).max(1.0e-12)
  } else {
    1.0
  }
  warranty_analysis(
    claims=claim_probability * cycles,
    expected_cost=cost * cycles,
    cost_per_unit_time=cost * cycles / (policy.duration * cycles),
    claim_probability~,
    renewal_cycles=cycles,
  )
}

///|
pub fn warranty_replacement_threshold(
  policy : WarrantyPolicy,
  administrative_cost : Double,
) -> Double {
  if policy.replacement_cost <= policy.salvage_value {
    0.0
  } else {
    administrative_cost / (policy.replacement_cost - policy.salvage_value)
  }
}

///|
pub fn preventive_replacement_cost(
  model : ReliabilityModel,
  age : Double,
  replacement_cost : Double,
) -> Double {
  if age <= 0.0 {
    abort("replacement age must be positive")
  }
  let failure_cost = replacement_cost * model.cdf(age)
  failure_cost / age
}

///|
pub fn optimize_replacement_age(
  model : ReliabilityModel,
  minimum_age : Double,
  maximum_age : Double,
  steps : Int,
  replacement_cost : Double,
) -> Double {
  let grid = linspace(minimum_age, maximum_age, steps)
  let costs = grid.map(age => {
    preventive_replacement_cost(model, age, replacement_cost)
  })
  let mut best = 0
  for i in 1..<costs.length() {
    if costs[i] < costs[best] {
      best = i
    }
  }
  grid[best]
}
