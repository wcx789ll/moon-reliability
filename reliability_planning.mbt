///|
/// Fleet-level planning metrics for engineering and SaaS operations.
pub struct FleetPlan {
  fleet_size : Int
  horizon : Double
  expected_failures : Double
  spare_units : Int
  stockout_probability : Double
  expected_downtime : Double
}

///|
pub fn fleet_plan(
  fleet_size~ : Int,
  horizon~ : Double,
  expected_failures~ : Double,
  spare_units~ : Int,
  stockout_probability~ : Double,
  expected_downtime~ : Double,
) -> FleetPlan {
  {
    fleet_size,
    horizon,
    expected_failures,
    spare_units,
    stockout_probability,
    expected_downtime,
  }
}

///|
pub fn expected_fleet_failures(
  model : ReliabilityModel,
  fleet_size : Int,
  horizon : Double,
) -> Double {
  if fleet_size < 0 || horizon < 0.0 {
    abort("invalid fleet dimensions")
  }
  fleet_size.to_double() * model.cdf(horizon)
}

///|
pub fn spare_stockout_probability(
  expected_failures : Double,
  spare_units : Int,
) -> Double {
  if expected_failures < 0.0 || spare_units < 0 {
    abort("invalid spare-stock arguments")
  }
  let mut cumulative = 0.0
  for failures in 0..<=spare_units {
    cumulative += @math.exp(-expected_failures) *
      @math.pow(expected_failures, failures.to_double()) /
      factorial(failures)
  }
  1.0 - cumulative
}

///|
pub fn plan_fleet(
  model : ReliabilityModel,
  fleet_size : Int,
  horizon : Double,
  target_stockout_probability : Double,
  repair_duration : Double,
) -> FleetPlan {
  let expected = expected_fleet_failures(model, fleet_size, horizon)
  let mut spares = 0
  while spare_stockout_probability(expected, spares) >
        target_stockout_probability &&
        spares < fleet_size * 2 + 100 {
    spares += 1
  }
  let stockout = spare_stockout_probability(expected, spares)
  fleet_plan(
    fleet_size~,
    horizon~,
    expected_failures=expected,
    spare_units=spares,
    stockout_probability=stockout,
    expected_downtime=expected * repair_duration,
  )
}

///|
pub fn fleet_reliability(
  model : ReliabilityModel,
  fleet_size : Int,
  horizon : Double,
  required_units : Int,
) -> Double {
  if required_units <= 0 || required_units > fleet_size {
    abort("invalid fleet requirement")
  }
  k_out_of_n_reliability(required_units, model.survival(horizon), fleet_size)
}

///|
pub fn service_capacity(
  arrival_rate : Double,
  average_service_time : Double,
  target_utilization : Double,
) -> Int {
  if arrival_rate < 0.0 ||
    average_service_time <= 0.0 ||
    target_utilization <= 0.0 ||
    target_utilization >= 1.0 {
    abort("invalid capacity inputs")
  }
  (arrival_rate * average_service_time / target_utilization)
  .ceil()
  .to_int()
  .max(1)
}

///|
pub fn expected_queue_wait(
  arrival_rate : Double,
  service_rate : Double,
  servers : Int,
) -> Double {
  if servers <= 0 || service_rate <= arrival_rate / servers.to_double() {
    return 1.0e300
  }
  1.0 / (servers.to_double() * service_rate - arrival_rate)
}

///|
pub fn service_level(
  model : ReliabilityModel,
  response_time : Double,
  target : Double,
) -> MetricEstimate {
  let achieved = model.survival(response_time)
  metric_estimate(
    estimate=achieved,
    lower=achieved,
    upper=achieved,
    confidence_level=target,
  )
}
