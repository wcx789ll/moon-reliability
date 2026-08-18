///|
/// Mission profile with multiple operating segments.
pub struct MissionSegment {
  start : Double
  duration : Double
  stress_multiplier : Double
}

///|
pub fn mission_segment(
  start~ : Double,
  duration~ : Double,
  stress_multiplier~ : Double,
) -> MissionSegment {
  if start < 0.0 || duration < 0.0 || stress_multiplier <= 0.0 {
    abort("invalid mission segment")
  }
  { start, duration, stress_multiplier }
}

///|
pub struct MissionResult {
  survival : Double
  cumulative_hazard : Double
  segment_hazards : Array[Double]
  expected_failures : Double
}

///|
pub fn mission_result(
  survival~ : Double,
  cumulative_hazard~ : Double,
  segment_hazards~ : Array[Double],
  expected_failures~ : Double,
) -> MissionResult {
  { survival, cumulative_hazard, segment_hazards, expected_failures }
}

///|
pub fn evaluate_mission(
  model : ReliabilityModel,
  segments : Array[MissionSegment],
) -> MissionResult {
  if segments.is_empty() {
    abort("mission needs segments")
  }
  let hazards = segments.map(segment => {
    model_hazard(model, segment.start) *
    segment.duration *
    segment.stress_multiplier
  })
  let cumulative = hazards.fold(init=0.0, (sum, value) => sum + value)
  mission_result(
    survival=@math.exp(-cumulative),
    cumulative_hazard=cumulative,
    segment_hazards=hazards,
    expected_failures=1.0 - @math.exp(-cumulative),
  )
}

///|
pub fn mission_profile_grid(
  start : Double,
  duration : Double,
  segments : Int,
  stress : Double,
) -> Array[MissionSegment] {
  let width = duration / segments.to_double()
  Array::makei(segments, i => {
    mission_segment(
      start=start + i.to_double() * width,
      duration=width,
      stress_multiplier=stress,
    )
  })
}

///|
pub fn mission_margin(
  result : MissionResult,
  target_survival : Double,
) -> Double {
  result.survival - target_survival
}

///|
pub fn mission_reliability_with_derating(
  model : ReliabilityModel,
  segments : Array[MissionSegment],
  derating : Double,
) -> Double {
  evaluate_mission(
    model,
    segments.map(segment => {
      ..segment,
      stress_multiplier: segment.stress_multiplier * derating,
    }),
  ).survival
}

///|
pub fn mission_stress_sensitivity(
  model : ReliabilityModel,
  segments : Array[MissionSegment],
  perturbation : Double,
) -> SensitivityPoint {
  let baseline = evaluate_mission(model, segments).survival
  let perturbed = mission_reliability_with_derating(
    model,
    segments,
    1.0 + perturbation,
  )
  sensitivity_point(
    parameter="stress multiplier",
    baseline~,
    perturbed~,
    absolute_change=perturbed - baseline,
    relative_change=(perturbed - baseline) / baseline.max(1.0e-300),
    elasticity=(perturbed - baseline) / baseline.max(1.0e-300) / perturbation,
  )
}
