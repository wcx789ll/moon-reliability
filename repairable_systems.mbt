///|
/// A repairable asset with failure and restoration rates.
pub struct RepairableAsset {
  asset_id : Int
  failure_rate : Double
  repair_rate : Double
  preventive_rate : Double
  spare_count : Int
  repair_cost : Double
  downtime_cost : Double
}

///|
pub fn repairable_asset(
  asset_id : Int,
  failure_rate : Double,
  repair_rate : Double,
  preventive_rate : Double,
  spare_count : Int,
  repair_cost : Double,
  downtime_cost : Double,
) -> RepairableAsset {
  if asset_id < 0 ||
    failure_rate < 0.0 ||
    repair_rate < 0.0 ||
    preventive_rate < 0.0 ||
    spare_count < 0 ||
    repair_cost < 0.0 ||
    downtime_cost < 0.0 {
    abort("invalid repairable asset")
  }
  {
    asset_id,
    failure_rate,
    repair_rate,
    preventive_rate,
    spare_count,
    repair_cost,
    downtime_cost,
  }
}

///|
pub fn repairable_asset_mtbf(asset : RepairableAsset) -> Double {
  if asset.failure_rate == 0.0 {
    1.0e300
  } else {
    1.0 / asset.failure_rate
  }
}

///|
pub fn repairable_asset_mttr(asset : RepairableAsset) -> Double {
  if asset.repair_rate == 0.0 {
    1.0e300
  } else {
    1.0 / asset.repair_rate
  }
}

///|
pub fn repairable_asset_inherent_availability(
  asset : RepairableAsset,
) -> Double {
  let total = asset.failure_rate + asset.repair_rate
  if total == 0.0 {
    1.0
  } else {
    asset.repair_rate / total
  }
}

///|
pub fn repairable_asset_steady_failure_probability(
  asset : RepairableAsset,
) -> Double {
  1.0 - repairable_asset_inherent_availability(asset)
}

///|
pub fn repairable_asset_effective_failure_rate(
  asset : RepairableAsset,
) -> Double {
  asset.failure_rate * (1.0 - asset.preventive_rate.min(1.0))
}

///|
pub fn repairable_asset_effective_availability(
  asset : RepairableAsset,
) -> Double {
  let failure = repairable_asset_effective_failure_rate(asset)
  let total = failure + asset.repair_rate
  if total == 0.0 {
    1.0
  } else {
    asset.repair_rate / total
  }
}

///|
pub fn repairable_asset_expected_failures(
  asset : RepairableAsset,
  horizon : Double,
) -> Double {
  if horizon < 0.0 {
    abort("horizon must be non-negative")
  }
  repairable_asset_effective_failure_rate(asset) * horizon
}

///|
pub fn repairable_asset_expected_downtime(
  asset : RepairableAsset,
  horizon : Double,
) -> Double {
  repairable_asset_expected_failures(asset, horizon) *
  repairable_asset_mttr(asset)
}

///|
pub fn repairable_asset_expected_cost(
  asset : RepairableAsset,
  horizon : Double,
) -> Double {
  repairable_asset_expected_failures(asset, horizon) * asset.repair_cost +
  repairable_asset_expected_downtime(asset, horizon) * asset.downtime_cost
}

///|
pub fn repairable_asset_reliability(
  asset : RepairableAsset,
  mission_time : Double,
) -> Double {
  if mission_time < 0.0 {
    abort("mission time must be non-negative")
  }
  @math.exp(-repairable_asset_effective_failure_rate(asset) * mission_time)
}

///|
pub struct RepairableSystem {
  assets : Array[RepairableAsset]
  architecture : String
  repair_capacity : Int
  spare_pool : Int
  name : String
}

///|
pub fn repairable_system(
  assets : Array[RepairableAsset],
  architecture : String,
  repair_capacity : Int,
  spare_pool : Int,
  name : String,
) -> RepairableSystem {
  if assets.is_empty() ||
    (architecture != "series" && architecture != "parallel") ||
    repair_capacity < 1 ||
    spare_pool < 0 {
    abort("invalid repairable system")
  }
  { assets, architecture, repair_capacity, spare_pool, name }
}

///|
pub fn repairable_system_asset_count(system : RepairableSystem) -> Int {
  system.assets.length()
}

///|
pub fn repairable_system_failure_rates(
  system : RepairableSystem,
) -> Array[Double] {
  system.assets.map(asset => asset.failure_rate)
}

///|
pub fn repairable_system_repair_rates(
  system : RepairableSystem,
) -> Array[Double] {
  system.assets.map(asset => asset.repair_rate)
}

///|
pub fn repairable_system_availability(system : RepairableSystem) -> Double {
  let values = system.assets.map(asset => {
    repairable_asset_effective_availability(asset)
  })
  if system.architecture == "series" {
    allocation_series_availability(values)
  } else {
    allocation_parallel_availability(values)
  }
}

///|
pub fn repairable_system_reliability(
  system : RepairableSystem,
  mission_time : Double,
) -> Double {
  let values = system.assets.map(asset => {
    repairable_asset_reliability(asset, mission_time)
  })
  if system.architecture == "series" {
    allocation_series_reliability(values)
  } else {
    allocation_parallel_reliability(values)
  }
}

///|
pub fn repairable_system_expected_failures(
  system : RepairableSystem,
  horizon : Double,
) -> Double {
  system.assets.fold(init=0.0, (total, asset) => {
    total + repairable_asset_expected_failures(asset, horizon)
  })
}

///|
pub fn repairable_system_expected_downtime(
  system : RepairableSystem,
  horizon : Double,
) -> Double {
  if system.architecture == "series" {
    system.assets.fold(init=0.0, (total, asset) => {
      total + repairable_asset_expected_downtime(asset, horizon)
    })
  } else {
    system.assets.fold(init=0.0, (total, asset) => {
      total + repairable_asset_expected_downtime(asset, horizon)
    }) /
    system.assets.length().to_double()
  }
}

///|
pub fn repairable_system_expected_cost(
  system : RepairableSystem,
  horizon : Double,
) -> Double {
  system.assets.fold(init=0.0, (total, asset) => {
    total + repairable_asset_expected_cost(asset, horizon)
  })
}

///|
pub fn repairable_system_spare_demand(
  system : RepairableSystem,
  horizon : Double,
) -> Double {
  repairable_system_expected_failures(system, horizon) /
  system.repair_capacity.to_double()
}

///|
pub fn repairable_system_spare_shortage(
  system : RepairableSystem,
  horizon : Double,
) -> Double {
  (repairable_system_spare_demand(system, horizon) -
  system.spare_pool.to_double()).max(0.0)
}

///|
pub fn repairable_system_spare_coverage(
  system : RepairableSystem,
  horizon : Double,
) -> Double {
  let demand = repairable_system_spare_demand(system, horizon)
  if demand == 0.0 {
    1.0
  } else {
    (system.spare_pool.to_double() / demand).min(1.0)
  }
}

///|
pub fn repairable_system_service_level(
  system : RepairableSystem,
  horizon : Double,
) -> Double {
  repairable_system_availability(system) *
  repairable_system_spare_coverage(system, horizon)
}

///|
pub struct RepairEvent {
  asset_id : Int
  failure_time : Double
  repair_start : Double
  repair_end : Double
  severity : Int
}

///|
pub fn repair_event(
  asset_id : Int,
  failure_time : Double,
  repair_start : Double,
  repair_end : Double,
  severity : Int,
) -> RepairEvent {
  if asset_id < 0 ||
    failure_time < 0.0 ||
    repair_start < failure_time ||
    repair_end < repair_start ||
    severity < 0 {
    abort("invalid repair event")
  }
  { asset_id, failure_time, repair_start, repair_end, severity }
}

///|
pub fn repair_event_wait(event : RepairEvent) -> Double {
  event.repair_start - event.failure_time
}

///|
pub fn repair_event_duration(event : RepairEvent) -> Double {
  event.repair_end - event.repair_start
}

///|
pub fn repair_event_total_outage(event : RepairEvent) -> Double {
  event.repair_end - event.failure_time
}

///|
pub fn repair_event_rate(_event : RepairEvent, horizon : Double) -> Double {
  if horizon <= 0.0 {
    abort("horizon must be positive")
  }
  1.0 / horizon
}

///|
pub fn repair_event_weight(event : RepairEvent) -> Double {
  (event.severity + 1).to_double() * repair_event_total_outage(event)
}

///|
pub struct RepairHistorySummary {
  event_count : Int
  total_wait : Double
  total_repair : Double
  total_outage : Double
  mean_wait : Double
  mean_repair : Double
  mean_outage : Double
  severity_weight : Double
  mtbf : Double
  mttr : Double
}

///|
pub fn repair_history_summary(
  events : Array[RepairEvent],
  horizon : Double,
) -> RepairHistorySummary {
  if horizon <= 0.0 {
    abort("horizon must be positive")
  }
  let wait = events.fold(init=0.0, (total, event) => {
    total + repair_event_wait(event)
  })
  let repair = events.fold(init=0.0, (total, event) => {
    total + repair_event_duration(event)
  })
  let outage = events.fold(init=0.0, (total, event) => {
    total + repair_event_total_outage(event)
  })
  let count = events.length()
  {
    event_count: count,
    total_wait: wait,
    total_repair: repair,
    total_outage: outage,
    mean_wait: if count == 0 {
      0.0
    } else {
      wait / count.to_double()
    },
    mean_repair: if count == 0 {
      0.0
    } else {
      repair / count.to_double()
    },
    mean_outage: if count == 0 {
      0.0
    } else {
      outage / count.to_double()
    },
    severity_weight: events.fold(init=0.0, (total, event) => {
      total + repair_event_weight(event)
    }),
    mtbf: if count == 0 {
      horizon
    } else {
      (horizon - outage).max(0.0) / count.to_double()
    },
    mttr: if count == 0 {
      0.0
    } else {
      repair / count.to_double()
    },
  }
}

///|
pub fn repair_history_availability(
  summary : RepairHistorySummary,
  horizon : Double,
) -> Double {
  if horizon <= 0.0 {
    abort("horizon must be positive")
  }
  (1.0 - summary.total_outage / horizon).max(0.0).min(1.0)
}

///|
pub fn repair_history_failure_rate(
  summary : RepairHistorySummary,
  horizon : Double,
) -> Double {
  if horizon <= 0.0 {
    abort("horizon must be positive")
  }
  summary.event_count.to_double() / horizon
}

///|
pub fn repair_history_weighted_availability(
  summary : RepairHistorySummary,
  horizon : Double,
) -> Double {
  let burden = summary.severity_weight / horizon
  (1.0 - burden).max(0.0).min(1.0)
}

///|
pub fn repair_history_checksum(summary : RepairHistorySummary) -> Double {
  summary.event_count.to_double() +
  summary.total_wait +
  summary.total_repair +
  summary.total_outage +
  summary.severity_weight +
  summary.mtbf +
  summary.mttr
}

///|
pub fn repair_events_by_asset(
  events : Array[RepairEvent],
  asset_id : Int,
) -> Array[RepairEvent] {
  events.filter(event => event.asset_id == asset_id)
}

///|
pub fn repair_event_asset_ids(events : Array[RepairEvent]) -> Array[Int] {
  let ids = []
  for event in events {
    if !ids.contains(event.asset_id) {
      ids.push(event.asset_id)
    }
  }
  ids.sort()
  ids
}

///|
pub fn repair_asset_failure_counts(events : Array[RepairEvent]) -> Array[Int] {
  repair_event_asset_ids(events).map(asset_id => {
    repair_events_by_asset(events, asset_id).length()
  })
}

///|
pub fn repair_asset_downtime(events : Array[RepairEvent]) -> Array[Double] {
  repair_event_asset_ids(events).map(asset_id => {
    repair_events_by_asset(events, asset_id).fold(init=0.0, (total, event) => {
      total + repair_event_total_outage(event)
    })
  })
}

///|
pub fn repair_asset_risk(events : Array[RepairEvent]) -> Array[Double] {
  repair_event_asset_ids(events).map(asset_id => {
    repair_events_by_asset(events, asset_id).fold(init=0.0, (total, event) => {
      total + repair_event_weight(event)
    })
  })
}

///|
pub fn repair_asset_rank(events : Array[RepairEvent]) -> Array[Int] {
  let ids = repair_event_asset_ids(events)
  ids.sort_by((left, right) => {
    let left_risk = repair_events_by_asset(events, left).fold(init=0.0, (
      total,
      event,
    ) => total + repair_event_weight(event))
    let right_risk = repair_events_by_asset(events, right).fold(init=0.0, (
      total,
      event,
    ) => total + repair_event_weight(event))
    if left_risk > right_risk {
      -1
    } else if left_risk < right_risk {
      1
    } else {
      0
    }
  })
  ids
}

///|
pub struct RepairQueuePlan {
  repairers : Int
  arrival_rate : Double
  service_rate : Double
  utilization : Double
  expected_queue : Double
  expected_wait : Double
  capacity : Double
  stable : Bool
}

///|
pub fn repair_queue_plan(
  repairers : Int,
  arrival_rate : Double,
  service_rate : Double,
) -> RepairQueuePlan {
  if repairers < 1 || arrival_rate < 0.0 || service_rate <= 0.0 {
    abort("invalid repair queue")
  }
  let capacity = repairers.to_double() * service_rate
  let utilization = arrival_rate / capacity
  let stable = utilization < 1.0
  let expected_queue = if stable {
    utilization * utilization / (1.0 - utilization).max(1.0e-12)
  } else {
    1.0e300
  }
  let expected_wait = if arrival_rate == 0.0 {
    0.0
  } else {
    expected_queue / arrival_rate
  }
  {
    repairers,
    arrival_rate,
    service_rate,
    utilization,
    expected_queue,
    expected_wait,
    capacity,
    stable,
  }
}

///|
pub fn repair_queue_is_stable(plan : RepairQueuePlan) -> Bool {
  plan.stable
}

///|
pub fn repair_queue_headroom(plan : RepairQueuePlan) -> Double {
  (plan.capacity - plan.arrival_rate).max(0.0)
}

///|
pub fn repair_queue_overload(plan : RepairQueuePlan) -> Double {
  (plan.arrival_rate - plan.capacity).max(0.0)
}

///|
pub fn repair_queue_plan_utilization(plan : RepairQueuePlan) -> Double {
  plan.utilization
}

///|
pub fn repair_queue_expected_queue(plan : RepairQueuePlan) -> Double {
  plan.expected_queue
}

///|
pub fn repair_queue_expected_wait(plan : RepairQueuePlan) -> Double {
  plan.expected_wait
}

///|
pub fn repair_queue_required_repairers(
  arrival_rate : Double,
  service_rate : Double,
  maximum_utilization : Double,
) -> Int {
  if arrival_rate < 0.0 ||
    service_rate <= 0.0 ||
    maximum_utilization <= 0.0 ||
    maximum_utilization >= 1.0 {
    abort("invalid repairer sizing inputs")
  }
  (arrival_rate / service_rate / maximum_utilization).ceil().to_int().max(1)
}

///|
pub fn repair_queue_plan_checksum(plan : RepairQueuePlan) -> Double {
  plan.repairers.to_double() +
  plan.arrival_rate +
  plan.service_rate +
  plan.utilization +
  plan.expected_queue +
  plan.expected_wait +
  plan.capacity
}

///|
pub fn repairable_system_queue_plan(
  system : RepairableSystem,
  horizon : Double,
  service_rate : Double,
) -> RepairQueuePlan {
  repair_queue_plan(
    system.repair_capacity,
    repairable_system_expected_failures(system, horizon) / horizon.max(1.0e-12),
    service_rate,
  )
}

///|
pub fn repairable_system_stability(
  system : RepairableSystem,
  horizon : Double,
  service_rate : Double,
) -> Bool {
  repair_queue_is_stable(
    repairable_system_queue_plan(system, horizon, service_rate),
  )
}

///|
pub fn repairable_system_target_spares(
  system : RepairableSystem,
  horizon : Double,
  target_coverage : Double,
) -> Int {
  if target_coverage <= 0.0 || target_coverage > 1.0 {
    abort("target coverage must be in (0, 1]")
  }
  (repairable_system_spare_demand(system, horizon) * target_coverage)
  .ceil()
  .to_int()
}

///|
pub fn repairable_system_add_spares(
  system : RepairableSystem,
  additional : Int,
) -> RepairableSystem {
  if additional < 0 {
    abort("additional spares must be non-negative")
  }
  { ..system, spare_pool: system.spare_pool + additional }
}

///|
pub fn repairable_system_change_repair_capacity(
  system : RepairableSystem,
  capacity : Int,
) -> RepairableSystem {
  if capacity < 1 {
    abort("repair capacity must be positive")
  }
  { ..system, repair_capacity: capacity }
}

///|
pub fn repairable_system_checksum(system : RepairableSystem) -> Double {
  system.assets.fold(
    init=system.repair_capacity.to_double() + system.spare_pool.to_double(),
    (total, asset) => {
      total +
      asset.asset_id.to_double() +
      asset.failure_rate +
      asset.repair_rate +
      asset.preventive_rate +
      asset.repair_cost +
      asset.downtime_cost
    },
  )
}

///|
pub fn repairable_asset_rank(
  assets : Array[RepairableAsset],
) -> Array[RepairableAsset] {
  let result = assets.copy()
  result.sort_by((left, right) => {
    let left_risk = left.failure_rate * left.downtime_cost
    let right_risk = right.failure_rate * right.downtime_cost
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
pub fn repairable_asset_risk_scores(
  assets : Array[RepairableAsset],
) -> Array[Double] {
  assets.map(asset => {
    asset.failure_rate * asset.downtime_cost +
    asset.repair_cost * asset.failure_rate
  })
}

///|
pub fn repairable_asset_cost_curve(
  asset : RepairableAsset,
  horizons : Array[Double],
) -> Array[Double] {
  horizons.map(horizon => repairable_asset_expected_cost(asset, horizon))
}

///|
pub fn repairable_asset_availability_curve(
  asset : RepairableAsset,
  horizons : Array[Double],
) -> Array[Double] {
  horizons.map(_ => repairable_asset_effective_availability(asset))
}

///|
pub fn repairable_asset_reliability_curve(
  asset : RepairableAsset,
  horizons : Array[Double],
) -> Array[Double] {
  horizons.map(horizon => repairable_asset_reliability(asset, horizon))
}

///|
pub fn repairable_system_curve(
  system : RepairableSystem,
  horizons : Array[Double],
) -> Array[Double] {
  horizons.map(horizon => repairable_system_reliability(system, horizon))
}

///|
pub fn repairable_system_availability_curve(
  system : RepairableSystem,
  horizons : Array[Double],
) -> Array[Double] {
  horizons.map(_ => repairable_system_availability(system))
}

///|
pub fn repairable_system_cost_curve(
  system : RepairableSystem,
  horizons : Array[Double],
) -> Array[Double] {
  horizons.map(horizon => repairable_system_expected_cost(system, horizon))
}

///|
pub fn repairable_system_checksum_curve(
  system : RepairableSystem,
  horizons : Array[Double],
) -> Double {
  repairable_system_curve(system, horizons).fold(init=0.0, (total, value) => {
    total + value
  })
}
