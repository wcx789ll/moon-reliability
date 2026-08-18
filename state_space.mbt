///|
/// Two-state continuous-time Markov availability model.
pub struct AvailabilityPoint {
  time : Double
  availability : Double
  unavailability : Double
  expected_failures : Double
}

///|
pub fn availability_point(
  time~ : Double,
  availability~ : Double,
  unavailability~ : Double,
  expected_failures~ : Double,
) -> AvailabilityPoint {
  { time, availability, unavailability, expected_failures }
}

///|
pub fn markov_availability(
  failure_rate : Double,
  repair_rate : Double,
  time : Double,
) -> Double {
  if failure_rate < 0.0 || repair_rate <= 0.0 || time < 0.0 {
    abort("invalid Markov rates")
  }
  let steady = repair_rate / (failure_rate + repair_rate)
  let transient = failure_rate / (failure_rate + repair_rate)
  steady + transient * @math.exp(-(failure_rate + repair_rate) * time)
}

///|
pub fn markov_availability_curve(
  failure_rate : Double,
  repair_rate : Double,
  horizon : Double,
  steps : Int,
) -> Array[AvailabilityPoint] {
  let grid = linspace(0.0, horizon, steps)
  grid.map(time => {
    let availability = markov_availability(failure_rate, repair_rate, time)
    availability_point(
      time~,
      availability~,
      unavailability=1.0 - availability,
      expected_failures=failure_rate * time,
    )
  })
}

///|
pub fn semi_markov_cycle_time(uptime : Double, downtime : Double) -> Double {
  if uptime < 0.0 || downtime < 0.0 {
    abort("cycle durations must be non-negative")
  }
  uptime + downtime
}

///|
pub fn alternating_renewal_availability(
  uptime : Double,
  downtime : Double,
) -> Double {
  let cycle = semi_markov_cycle_time(uptime, downtime)
  if cycle == 0.0 {
    0.0
  } else {
    uptime / cycle
  }
}

///|
pub fn cold_standby_reliability(
  primary : ReliabilityModel,
  standby : ReliabilityModel,
  switch_probability : Double,
  time : Double,
) -> Double {
  if switch_probability < 0.0 || switch_probability > 1.0 {
    abort("switch probability outside [0, 1]")
  }
  let primary_survival = primary.survival(time)
  let standby_path = (1.0 - primary_survival) *
    switch_probability *
    standby.survival(time)
  primary_survival + standby_path
}

///|
pub fn warm_standby_reliability(
  primary : ReliabilityModel,
  standby : ReliabilityModel,
  time : Double,
) -> Double {
  1.0 - (1.0 - primary.survival(time)) * (1.0 - standby.survival(time))
}

///|
pub fn expected_downtime(model : ReliabilityModel, horizon : Double) -> Double {
  horizon * (1.0 - model.survival(horizon))
}

///|
pub fn expected_failures_in_window(
  model : ReliabilityModel,
  start : Double,
  stop : Double,
) -> Double {
  let first = model_hazard(model, start)
  let second = model_hazard(model, stop)
  (first + second) / 2.0 * (stop - start)
}
