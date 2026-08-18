///|
/// Contractual reliability requirement over a set of mission checkpoints.
pub struct ReliabilityRequirement {
  name : String
  mission_time : Double
  minimum_survival : Double
  confidence_level : Double
  penalty : Double
}

///|
pub fn reliability_requirement(
  name~ : String,
  mission_time~ : Double,
  minimum_survival~ : Double,
  confidence_level~ : Double,
  penalty~ : Double,
) -> ReliabilityRequirement {
  if mission_time < 0.0 ||
    minimum_survival < 0.0 ||
    minimum_survival > 1.0 ||
    confidence_level <= 0.0 ||
    confidence_level >= 1.0 ||
    penalty < 0.0 {
    abort("invalid reliability requirement")
  }
  { name, mission_time, minimum_survival, confidence_level, penalty }
}

///|
pub struct RequirementResult {
  requirement : String
  estimate : Double
  lower_bound : Double
  margin : Double
  passed : Bool
  penalty : Double
  explanation : String
}

///|
pub fn requirement_result(
  requirement~ : String,
  estimate~ : Double,
  lower_bound~ : Double,
  margin~ : Double,
  passed~ : Bool,
  penalty~ : Double,
  explanation~ : String,
) -> RequirementResult {
  { requirement, estimate, lower_bound, margin, passed, penalty, explanation }
}

///|
pub fn evaluate_requirement(
  model : ReliabilityModel,
  requirement : ReliabilityRequirement,
) -> RequirementResult {
  let metric = model_metric(
    model,
    requirement.mission_time,
    requirement.confidence_level,
  )
  let margin = metric.lower - requirement.minimum_survival
  let passed = margin >= 0.0
  requirement_result(
    requirement=requirement.name,
    estimate=metric.estimate,
    lower_bound=metric.lower,
    margin~,
    passed~,
    penalty=if passed { 0.0 } else { requirement.penalty },
    explanation=if passed {
      "requirement satisfied at requested confidence"
    } else {
      "lower confidence bound is below requirement"
    },
  )
}

///|
pub fn evaluate_requirements(
  model : ReliabilityModel,
  requirements : Array[ReliabilityRequirement],
) -> Array[RequirementResult] {
  requirements.map(requirement => evaluate_requirement(model, requirement))
}

///|
pub fn requirement_pass_rate(results : Array[RequirementResult]) -> Double {
  if results.is_empty() {
    return 1.0
  }
  results.filter(result => result.passed).length().to_double() /
  results.length().to_double()
}

///|
pub fn total_contract_penalty(results : Array[RequirementResult]) -> Double {
  results.fold(init=0.0, (sum, result) => sum + result.penalty)
}

///|
pub fn contract_summary(results : Array[RequirementResult]) -> String {
  let builder = StringBuilder::new()
  builder.write_string(
    "requirement,estimate,lower_bound,margin,passed,penalty\n",
  )
  for result in results {
    builder.write_string(
      "\{result.requirement},\{result.estimate},\{result.lower_bound},\{result.margin},\{result.passed},\{result.penalty}\n",
    )
  }
  builder.to_string()
}

///|
pub fn mission_profile_requirement(
  name : String,
  model : ReliabilityModel,
  checkpoints : Array[Double],
  target : Double,
  confidence : Double,
  penalty : Double,
) -> Array[ReliabilityRequirement] {
  ignore(model)
  checkpoints.map(time => {
    reliability_requirement(
      name~,
      mission_time=time,
      minimum_survival=target,
      confidence_level=confidence,
      penalty~,
    )
  })
}

///|
pub fn requirement_breach_time(
  model : ReliabilityModel,
  target : Double,
  confidence : Double,
  start : Double,
  stop : Double,
  steps : Int,
) -> Double? {
  let grid = linspace(start, stop, steps)
  for time in grid {
    let metric = model_metric(model, time, confidence)
    if metric.lower < target {
      return Some(time)
    }
  }
  None
}

///|
pub fn required_scale_for_mission(
  shape : Double,
  target : Double,
  mission_time : Double,
) -> Double {
  if shape <= 0.0 || target <= 0.0 || target >= 1.0 || mission_time <= 0.0 {
    abort("invalid scale requirement")
  }
  mission_time / @math.pow(-@math.ln(target), 1.0 / shape)
}

///|
pub fn required_sample_size(
  expected_proportion : Double,
  half_width : Double,
  confidence : Double,
) -> Int {
  if expected_proportion <= 0.0 ||
    expected_proportion >= 1.0 ||
    half_width <= 0.0 {
    abort("invalid sample-size inputs")
  }
  let z = standard_normal_inv(0.5 + confidence / 2.0)
  (z *
  z *
  expected_proportion *
  (1.0 - expected_proportion) /
  (half_width * half_width))
  .ceil()
  .to_int()
}

///|
pub fn acceptance_number(
  sample_size : Int,
  allowable_failure_rate : Double,
) -> Int {
  if sample_size <= 0 ||
    allowable_failure_rate < 0.0 ||
    allowable_failure_rate > 1.0 {
    abort("invalid acceptance plan")
  }
  (sample_size.to_double() * allowable_failure_rate).floor().to_int()
}

///|
pub fn demonstrate_reliability(
  model : ReliabilityModel,
  times : Array[Double],
) -> Array[MetricEstimate] {
  times.map(time => model_metric(model, time, 0.95))
}
