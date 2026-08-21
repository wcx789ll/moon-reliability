///|
/// Operational state of an installed or tested asset.
pub(all) enum FleetAssetState {
  FleetActive
  FleetFailed
  FleetRetired
  FleetMaintenance
} derive(Debug, Eq)

///|
/// A unit-level record used by fleet reliability and availability analysis.
pub struct FleetAsset {
  asset_id : Int
  model_code : String
  cohort : Int
  commissioned_at : Double
  as_of : Double
  state : FleetAssetState
  operating_hours : Double
  failure_count : Int
  repair_hours : Double
  criticality : Double
  utilization : Double
}

///|
pub fn fleet_asset(
  asset_id : Int,
  model_code : String,
  cohort : Int,
  commissioned_at : Double,
  as_of : Double,
  state : FleetAssetState,
  operating_hours : Double,
  failure_count : Int,
  repair_hours : Double,
  criticality : Double,
  utilization : Double,
) -> FleetAsset {
  if asset_id < 0 ||
    cohort < 0 ||
    commissioned_at < 0.0 ||
    as_of < commissioned_at ||
    operating_hours < 0.0 ||
    failure_count < 0 ||
    repair_hours < 0.0 ||
    criticality < 0.0 ||
    utilization < 0.0 ||
    utilization > 1.0 {
    abort("invalid fleet asset")
  }
  {
    asset_id,
    model_code,
    cohort,
    commissioned_at,
    as_of,
    state,
    operating_hours,
    failure_count,
    repair_hours,
    criticality,
    utilization,
  }
}

///|
pub fn fleet_asset_age(asset : FleetAsset) -> Double {
  (asset.as_of - asset.commissioned_at).max(0.0)
}

///|
pub fn fleet_asset_exposure(asset : FleetAsset) -> Double {
  asset.operating_hours * asset.utilization
}

///|
pub fn fleet_asset_is_operational(asset : FleetAsset) -> Bool {
  asset.state is FleetActive
}

///|
pub fn fleet_asset_is_unavailable(asset : FleetAsset) -> Bool {
  asset.state is FleetFailed || asset.state is FleetMaintenance
}

///|
pub fn fleet_asset_failure_rate(asset : FleetAsset) -> Double {
  if fleet_asset_exposure(asset) <= 0.0 {
    0.0
  } else {
    asset.failure_count.to_double() / fleet_asset_exposure(asset)
  }
}

///|
pub fn fleet_asset_repair_rate(asset : FleetAsset) -> Double {
  if asset.failure_count == 0 || asset.repair_hours <= 0.0 {
    0.0
  } else {
    asset.failure_count.to_double() / asset.repair_hours
  }
}

///|
pub fn fleet_asset_mtbf(asset : FleetAsset) -> Double {
  if asset.failure_count == 0 {
    fleet_asset_exposure(asset)
  } else {
    fleet_asset_exposure(asset) / asset.failure_count.to_double()
  }
}

///|
pub fn fleet_asset_mttr(asset : FleetAsset) -> Double {
  if asset.failure_count == 0 {
    0.0
  } else {
    asset.repair_hours / asset.failure_count.to_double()
  }
}

///|
pub fn fleet_asset_inherent_availability(asset : FleetAsset) -> Double {
  let mtbf = fleet_asset_mtbf(asset)
  let mttr = fleet_asset_mttr(asset)
  if mtbf + mttr == 0.0 {
    1.0
  } else {
    mtbf / (mtbf + mttr)
  }
}

///|
pub fn fleet_asset_weight(asset : FleetAsset) -> Double {
  asset.criticality.max(0.0) * (1.0 + asset.utilization)
}

///|
pub struct FleetObservation {
  assets : Array[FleetAsset]
  start : Double
  end : Double
  name : String
}

///|
pub fn fleet_observation(
  assets : Array[FleetAsset],
  start : Double,
  end : Double,
  name : String,
) -> FleetObservation {
  if end <= start {
    abort("fleet observation end must exceed start")
  }
  if assets.is_empty() {
    abort("fleet observation requires at least one asset")
  }
  { assets, start, end, name }
}

///|
pub fn fleet_observation_duration(observation : FleetObservation) -> Double {
  observation.end - observation.start
}

///|
pub fn fleet_asset_count(observation : FleetObservation) -> Int {
  observation.assets.length()
}

///|
pub fn fleet_active_count(observation : FleetObservation) -> Int {
  observation.assets.fold(init=0, (count, asset) => {
    if asset.state is FleetActive {
      count + 1
    } else {
      count
    }
  })
}

///|
pub fn fleet_failed_count(observation : FleetObservation) -> Int {
  observation.assets.fold(init=0, (count, asset) => {
    if asset.state is FleetFailed {
      count + 1
    } else {
      count
    }
  })
}

///|
pub fn fleet_maintenance_count(observation : FleetObservation) -> Int {
  observation.assets.fold(init=0, (count, asset) => {
    if asset.state is FleetMaintenance {
      count + 1
    } else {
      count
    }
  })
}

///|
pub fn fleet_retired_count(observation : FleetObservation) -> Int {
  observation.assets.fold(init=0, (count, asset) => {
    if asset.state is FleetRetired {
      count + 1
    } else {
      count
    }
  })
}

///|
pub fn fleet_unavailable_fraction(observation : FleetObservation) -> Double {
  let total = fleet_asset_count(observation)
  if total == 0 {
    0.0
  } else {
    (fleet_failed_count(observation) + fleet_maintenance_count(observation)).to_double() /
    total.to_double()
  }
}

///|
pub fn fleet_state_fraction(
  observation : FleetObservation,
  state : FleetAssetState,
) -> Double {
  let count = observation.assets.fold(init=0, (total, asset) => {
    if asset.state == state {
      total + 1
    } else {
      total
    }
  })
  count.to_double() / fleet_asset_count(observation).to_double()
}

///|
pub fn fleet_total_operating_hours(observation : FleetObservation) -> Double {
  observation.assets.fold(init=0.0, (total, asset) => {
    total + asset.operating_hours
  })
}

///|
pub fn fleet_total_failure_count(observation : FleetObservation) -> Int {
  observation.assets.fold(init=0, (total, asset) => total + asset.failure_count)
}

///|
pub fn fleet_total_repair_hours(observation : FleetObservation) -> Double {
  observation.assets.fold(init=0.0, (total, asset) => total + asset.repair_hours)
}

///|
pub fn fleet_total_criticality(observation : FleetObservation) -> Double {
  observation.assets.fold(init=0.0, (total, asset) => total + asset.criticality)
}

///|
pub fn fleet_weighted_availability(observation : FleetObservation) -> Double {
  let denominator = observation.assets.fold(init=0.0, (total, asset) => {
    total + fleet_asset_weight(asset)
  })
  if denominator == 0.0 {
    1.0
  } else {
    observation.assets.fold(init=0.0, (total, asset) => {
      total +
      fleet_asset_weight(asset) * fleet_asset_inherent_availability(asset)
    }) /
    denominator
  }
}

///|
pub fn fleet_average_age(observation : FleetObservation) -> Double {
  mean(observation.assets.map(asset => fleet_asset_age(asset)))
}

///|
pub fn fleet_age_quantile(
  observation : FleetObservation,
  probability : Double,
) -> Double {
  quantile(observation.assets.map(asset => fleet_asset_age(asset)), probability)
}

///|
pub fn fleet_failure_rate(observation : FleetObservation) -> Double {
  let exposure = fleet_total_operating_hours(observation)
  if exposure == 0.0 {
    0.0
  } else {
    fleet_total_failure_count(observation).to_double() / exposure
  }
}

///|
pub fn fleet_repair_rate(observation : FleetObservation) -> Double {
  let hours = fleet_total_repair_hours(observation)
  if hours == 0.0 {
    0.0
  } else {
    fleet_total_failure_count(observation).to_double() / hours
  }
}

///|
pub fn fleet_mtbf(observation : FleetObservation) -> Double {
  let failures = fleet_total_failure_count(observation)
  if failures == 0 {
    fleet_total_operating_hours(observation)
  } else {
    fleet_total_operating_hours(observation) / failures.to_double()
  }
}

///|
pub fn fleet_mttr(observation : FleetObservation) -> Double {
  let failures = fleet_total_failure_count(observation)
  if failures == 0 {
    0.0
  } else {
    fleet_total_repair_hours(observation) / failures.to_double()
  }
}

///|
pub fn fleet_inherent_availability(observation : FleetObservation) -> Double {
  let mtbf = fleet_mtbf(observation)
  let mttr = fleet_mttr(observation)
  if mtbf + mttr == 0.0 {
    1.0
  } else {
    mtbf / (mtbf + mttr)
  }
}

///|
pub fn fleet_expected_failures(
  observation : FleetObservation,
  horizon : Double,
) -> Double {
  if horizon < 0.0 {
    abort("horizon must be non-negative")
  }
  fleet_failure_rate(observation) *
  horizon *
  fleet_asset_count(observation).to_double()
}

///|
pub fn fleet_expected_downtime(
  observation : FleetObservation,
  horizon : Double,
) -> Double {
  fleet_expected_failures(observation, horizon) * fleet_mttr(observation)
}

///|
pub fn fleet_availability_projection(
  observation : FleetObservation,
  horizons : Array[Double],
) -> Array[Double] {
  horizons.map(horizon => {
    let downtime = fleet_expected_downtime(observation, horizon)
    (1.0 - downtime / horizon.max(1.0e-12)).max(0.0).min(1.0)
  })
}

///|
pub fn fleet_reliability_projection(
  observation : FleetObservation,
  horizons : Array[Double],
) -> Array[Double] {
  let rate = fleet_failure_rate(observation)
  horizons.map(horizon => {
    @math.exp(-rate * horizon * fleet_asset_count(observation).to_double())
  })
}

///|
pub fn fleet_critical_assets(
  observation : FleetObservation,
  minimum_criticality : Double,
) -> Array[FleetAsset] {
  observation.assets.filter(asset => asset.criticality >= minimum_criticality)
}

///|
pub fn fleet_high_risk_assets(
  observation : FleetObservation,
  failure_rate_limit : Double,
  availability_limit : Double,
) -> Array[FleetAsset] {
  observation.assets.filter(asset => {
    fleet_asset_failure_rate(asset) >= failure_rate_limit ||
    fleet_asset_inherent_availability(asset) <= availability_limit
  })
}

///|
pub fn fleet_rank_by_risk(observation : FleetObservation) -> Array[FleetAsset] {
  let result = observation.assets.copy()
  result.sort_by((left, right) => {
    let left_score = fleet_asset_failure_rate(left) * fleet_asset_weight(left)
    let right_score = fleet_asset_failure_rate(right) *
      fleet_asset_weight(right)
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

///|
pub fn fleet_risk_score(asset : FleetAsset) -> Double {
  fleet_asset_failure_rate(asset) *
  fleet_asset_weight(asset) *
  (1.0 + fleet_asset_age(asset))
}

///|
pub fn fleet_risk_scores(observation : FleetObservation) -> Array[Double] {
  observation.assets.map(asset => fleet_risk_score(asset))
}

///|
pub fn fleet_risk_concentration(
  observation : FleetObservation,
  top_count : Int,
) -> Double {
  if top_count <= 0 {
    abort("top_count must be positive")
  }
  let ranked = fleet_rank_by_risk(observation)
  let limit = top_count.min(ranked.length())
  let top = Array::makei(limit, i => fleet_risk_score(ranked[i]))
  let total = fleet_risk_scores(observation).fold(init=0.0, (sum, value) => {
    sum + value
  })
  if total == 0.0 {
    0.0
  } else {
    top.fold(init=0.0, (sum, value) => sum + value) / total
  }
}

///|
pub fn fleet_group_ids(observation : FleetObservation) -> Array[Int] {
  let ids = []
  for asset in observation.assets {
    if !ids.contains(asset.cohort) {
      ids.push(asset.cohort)
    }
  }
  ids.sort()
  ids
}

///|
pub fn fleet_model_codes(observation : FleetObservation) -> Array[String] {
  let codes : Array[String] = []
  for asset in observation.assets {
    if !codes.contains(asset.model_code) {
      codes.push(asset.model_code)
    }
  }
  codes.sort()
  codes
}

///|
pub fn fleet_filter_cohort(
  observation : FleetObservation,
  cohort : Int,
) -> FleetObservation {
  fleet_observation(
    observation.assets.filter(asset => asset.cohort == cohort),
    observation.start,
    observation.end,
    "cohort-{cohort}",
  )
}

///|
pub fn fleet_filter_model(
  observation : FleetObservation,
  model_code : String,
) -> FleetObservation {
  fleet_observation(
    observation.assets.filter(asset => asset.model_code == model_code),
    observation.start,
    observation.end,
    model_code,
  )
}

///|
pub fn fleet_group_summary(
  observation : FleetObservation,
  cohort : Int,
) -> FleetSummary {
  fleet_summary(fleet_filter_cohort(observation, cohort))
}

///|
pub struct FleetSummary {
  asset_count : Int
  active_count : Int
  failed_count : Int
  maintenance_count : Int
  retired_count : Int
  average_age : Double
  total_exposure : Double
  failure_rate : Double
  mtbf : Double
  mttr : Double
  availability : Double
  weighted_availability : Double
  expected_failures : Double
  criticality : Double
}

///|
pub fn fleet_summary(observation : FleetObservation) -> FleetSummary {
  {
    asset_count: fleet_asset_count(observation),
    active_count: fleet_active_count(observation),
    failed_count: fleet_failed_count(observation),
    maintenance_count: fleet_maintenance_count(observation),
    retired_count: fleet_retired_count(observation),
    average_age: fleet_average_age(observation),
    total_exposure: fleet_total_operating_hours(observation),
    failure_rate: fleet_failure_rate(observation),
    mtbf: fleet_mtbf(observation),
    mttr: fleet_mttr(observation),
    availability: fleet_inherent_availability(observation),
    weighted_availability: fleet_weighted_availability(observation),
    expected_failures: fleet_expected_failures(
      observation,
      fleet_observation_duration(observation),
    ),
    criticality: fleet_total_criticality(observation),
  }
}

///|
pub fn fleet_summaries_by_cohort(
  observation : FleetObservation,
) -> Array[FleetSummary] {
  fleet_group_ids(observation).map(cohort => {
    fleet_group_summary(observation, cohort)
  })
}

///|
pub fn fleet_summaries_by_model(
  observation : FleetObservation,
) -> Array[FleetSummary] {
  fleet_model_codes(observation).map(model => {
    fleet_summary(fleet_filter_model(observation, model))
  })
}

///|
pub struct FleetReliabilityPoint {
  horizon : Double
  reliability : Double
  availability : Double
  expected_failures : Double
  expected_downtime : Double
}

///|
pub fn fleet_reliability_point(
  horizon : Double,
  reliability : Double,
  availability : Double,
  expected_failures : Double,
  expected_downtime : Double,
) -> FleetReliabilityPoint {
  { horizon, reliability, availability, expected_failures, expected_downtime }
}

///|
pub fn fleet_reliability_curve(
  observation : FleetObservation,
  horizons : Array[Double],
) -> Array[FleetReliabilityPoint] {
  let rate = fleet_failure_rate(observation)
  horizons.map(horizon => {
    let reliability = @math.exp(
      -rate * horizon * fleet_asset_count(observation).to_double(),
    )
    let failures = fleet_expected_failures(observation, horizon)
    let downtime = fleet_expected_downtime(observation, horizon)
    fleet_reliability_point(
      horizon,
      reliability,
      (1.0 - downtime / horizon.max(1.0e-12)).max(0.0).min(1.0),
      failures,
      downtime,
    )
  })
}

///|
pub fn fleet_curve_checksum(curve : Array[FleetReliabilityPoint]) -> Double {
  curve.fold(init=0.0, (total, point) => {
    total +
    point.horizon +
    point.reliability +
    point.availability +
    point.expected_failures +
    point.expected_downtime
  })
}

///|
pub fn fleet_reliability_at(
  observation : FleetObservation,
  horizon : Double,
) -> Double {
  if horizon < 0.0 {
    abort("horizon must be non-negative")
  }
  fleet_reliability_projection(observation, [horizon])[0]
}

///|
pub fn fleet_availability_at(
  observation : FleetObservation,
  horizon : Double,
) -> Double {
  if horizon < 0.0 {
    abort("horizon must be non-negative")
  }
  fleet_availability_projection(observation, [horizon])[0]
}

///|
pub fn fleet_target_horizon(
  observation : FleetObservation,
  target_reliability : Double,
) -> Double {
  if target_reliability <= 0.0 || target_reliability >= 1.0 {
    abort("target reliability must be between zero and one")
  }
  let rate = fleet_failure_rate(observation) *
    fleet_asset_count(observation).to_double()
  if rate == 0.0 {
    1.0e300
  } else {
    -@math.ln(target_reliability) / rate
  }
}

///|
pub fn fleet_target_failures(
  observation : FleetObservation,
  horizon : Double,
  maximum_expected_failures : Double,
) -> Bool {
  fleet_expected_failures(observation, horizon) <= maximum_expected_failures
}

///|
pub fn fleet_replacement_candidates(
  observation : FleetObservation,
  age_limit : Double,
  risk_limit : Double,
) -> Array[FleetAsset] {
  observation.assets.filter(asset => {
    fleet_asset_age(asset) >= age_limit || fleet_risk_score(asset) >= risk_limit
  })
}

///|
pub fn fleet_maintenance_candidates(
  observation : FleetObservation,
  availability_limit : Double,
) -> Array[FleetAsset] {
  observation.assets.filter(asset => {
    asset.state is FleetActive &&
    fleet_asset_inherent_availability(asset) < availability_limit
  })
}

///|
pub fn fleet_retirement_candidates(
  observation : FleetObservation,
  age_limit : Double,
  minimum_utilization : Double,
) -> Array[FleetAsset] {
  observation.assets.filter(asset => {
    fleet_asset_age(asset) >= age_limit &&
    asset.utilization < minimum_utilization
  })
}

///|
pub fn fleet_capacity(observation : FleetObservation) -> Double {
  observation.assets.fold(init=0.0, (total, asset) => total + asset.utilization)
}

///|
pub fn fleet_used_capacity(observation : FleetObservation) -> Double {
  observation.assets.fold(init=0.0, (total, asset) => {
    if fleet_asset_is_operational(asset) {
      total + asset.utilization
    } else {
      total
    }
  })
}

///|
pub fn fleet_capacity_utilization(observation : FleetObservation) -> Double {
  let capacity = fleet_capacity(observation)
  if capacity == 0.0 {
    0.0
  } else {
    fleet_used_capacity(observation) / capacity
  }
}

///|
pub fn fleet_load_headroom(
  observation : FleetObservation,
  target_utilization : Double,
) -> Double {
  if target_utilization < 0.0 || target_utilization > 1.0 {
    abort("target utilization must be in [0, 1]")
  }
  (fleet_capacity(observation) * target_utilization -
  fleet_used_capacity(observation)).max(0.0)
}

///|
pub fn fleet_asset_by_id(
  observation : FleetObservation,
  asset_id : Int,
) -> FleetAsset? {
  for asset in observation.assets {
    if asset.asset_id == asset_id {
      return Some(asset)
    }
  }
  None
}

///|
pub fn fleet_ids(observation : FleetObservation) -> Array[Int] {
  observation.assets.map(asset => asset.asset_id)
}

///|
pub fn fleet_exposure_by_cohort(
  observation : FleetObservation,
) -> Array[Double] {
  fleet_group_ids(observation).map(cohort => {
    observation.assets.fold(init=0.0, (total, asset) => {
      if asset.cohort == cohort {
        total + fleet_asset_exposure(asset)
      } else {
        total
      }
    })
  })
}

///|
pub fn fleet_failures_by_cohort(observation : FleetObservation) -> Array[Int] {
  fleet_group_ids(observation).map(cohort => {
    observation.assets.fold(init=0, (total, asset) => {
      if asset.cohort == cohort {
        total + asset.failure_count
      } else {
        total
      }
    })
  })
}

///|
pub fn fleet_failure_rate_by_cohort(
  observation : FleetObservation,
) -> Array[Double] {
  let exposures = fleet_exposure_by_cohort(observation)
  let failures = fleet_failures_by_cohort(observation)
  Array::makei(exposures.length(), i => {
    if exposures[i] == 0.0 {
      0.0
    } else {
      failures[i].to_double() / exposures[i]
    }
  })
}

///|
pub fn fleet_cohort_comparison(observation : FleetObservation) -> Array[Double] {
  let rates = fleet_failure_rate_by_cohort(observation)
  if rates.is_empty() {
    []
  } else {
    rates.map(rate => rate - mean(rates))
  }
}

///|
pub fn fleet_model_failure_rates(
  observation : FleetObservation,
) -> Array[Double] {
  fleet_model_codes(observation).map(model => {
    fleet_failure_rate(fleet_filter_model(observation, model))
  })
}

///|
pub fn fleet_model_availability(
  observation : FleetObservation,
) -> Array[Double] {
  fleet_model_codes(observation).map(model => {
    fleet_inherent_availability(fleet_filter_model(observation, model))
  })
}

///|
pub fn fleet_model_risk_rank(observation : FleetObservation) -> Array[String] {
  let models = fleet_model_codes(observation)
  let result = models.copy()
  result.sort_by((left, right) => {
    let left_rate = fleet_failure_rate(fleet_filter_model(observation, left))
    let right_rate = fleet_failure_rate(fleet_filter_model(observation, right))
    if left_rate > right_rate {
      -1
    } else if left_rate < right_rate {
      1
    } else {
      0
    }
  })
  result
}

///|
pub fn fleet_change_rate(
  previous : FleetObservation,
  current : FleetObservation,
) -> Double {
  let previous_rate = fleet_failure_rate(previous)
  let current_rate = fleet_failure_rate(current)
  if previous_rate == 0.0 {
    current_rate
  } else {
    (current_rate - previous_rate) / previous_rate
  }
}

///|
pub fn fleet_availability_change(
  previous : FleetObservation,
  current : FleetObservation,
) -> Double {
  fleet_inherent_availability(current) - fleet_inherent_availability(previous)
}

///|
pub fn fleet_health_index(observation : FleetObservation) -> Double {
  let availability = fleet_weighted_availability(observation)
  let risk = fleet_failure_rate(observation) * fleet_average_age(observation)
  (availability * @math.exp(-risk)).max(0.0).min(1.0)
}

///|
pub fn fleet_health_label(index : Double) -> String {
  if index >= 0.9 {
    "healthy"
  } else if index >= 0.7 {
    "watch"
  } else if index >= 0.5 {
    "degraded"
  } else {
    "critical"
  }
}

///|
pub fn fleet_health_gap(
  observation : FleetObservation,
  target : Double,
) -> Double {
  (target - fleet_health_index(observation)).max(0.0)
}

///|
pub fn fleet_action_priority(
  asset : FleetAsset,
  target_availability : Double,
) -> Double {
  let availability_gap = (target_availability -
  fleet_asset_inherent_availability(asset)).max(0.0)
  availability_gap * (1.0 + asset.criticality) * (1.0 + fleet_asset_age(asset))
}

///|
pub fn fleet_action_priorities(
  observation : FleetObservation,
  target_availability : Double,
) -> Array[Double] {
  observation.assets.map(asset => {
    fleet_action_priority(asset, target_availability)
  })
}

///|
pub fn fleet_action_rank(
  observation : FleetObservation,
  target_availability : Double,
) -> Array[FleetAsset] {
  let result = observation.assets.copy()
  result.sort_by((left, right) => {
    let left_priority = fleet_action_priority(left, target_availability)
    let right_priority = fleet_action_priority(right, target_availability)
    if left_priority > right_priority {
      -1
    } else if left_priority < right_priority {
      1
    } else {
      0
    }
  })
  result
}

///|
pub fn fleet_action_budget(
  observation : FleetObservation,
  target_availability : Double,
  budget : Int,
) -> Array[FleetAsset] {
  if budget < 0 {
    abort("budget must be non-negative")
  }
  let ranked = fleet_action_rank(observation, target_availability)
  let count = budget.min(ranked.length())
  Array::makei(count, i => ranked[i])
}

///|
pub fn fleet_snapshot_checksum(observation : FleetObservation) -> Double {
  observation.assets.fold(init=0.0, (total, asset) => {
    total +
    asset.asset_id.to_double() +
    fleet_asset_age(asset) +
    asset.operating_hours +
    asset.failure_count.to_double() +
    asset.repair_hours +
    asset.criticality +
    asset.utilization
  })
}

///|
pub fn fleet_merge_observations(
  left : FleetObservation,
  right : FleetObservation,
) -> FleetObservation {
  if left.end > right.start && right.end > left.start {
    abort("fleet observation windows overlap")
  }
  fleet_observation(
    left.assets + right.assets,
    left.start.min(right.start),
    left.end.max(right.end),
    "{left.name}+{right.name}",
  )
}

///|
pub fn fleet_asset_age_bands(
  observation : FleetObservation,
  boundaries : Array[Double],
) -> Array[Int] {
  if boundaries.is_empty() {
    abort("age boundaries must not be empty")
  }
  let sorted = boundaries.copy()
  sorted.sort()
  Array::makei(sorted.length() + 1, i => {
    let lower = if i == 0 { -1.0e300 } else { sorted[i - 1] }
    let upper = if i == sorted.length() { 1.0e300 } else { sorted[i] }
    observation.assets.fold(init=0, (count, asset) => {
      let age = fleet_asset_age(asset)
      if age >= lower && age < upper {
        count + 1
      } else {
        count
      }
    })
  })
}

///|
pub fn fleet_utilization_bands(
  observation : FleetObservation,
  boundaries : Array[Double],
) -> Array[Int] {
  if boundaries.is_empty() {
    abort("utilization boundaries must not be empty")
  }
  let sorted = boundaries.copy()
  sorted.sort()
  Array::makei(sorted.length() + 1, i => {
    let lower = if i == 0 { -1.0e300 } else { sorted[i - 1] }
    let upper = if i == sorted.length() { 1.0e300 } else { sorted[i] }
    observation.assets.fold(init=0, (count, asset) => {
      if asset.utilization >= lower && asset.utilization < upper {
        count + 1
      } else {
        count
      }
    })
  })
}

///|
pub fn fleet_criticality_bands(
  observation : FleetObservation,
  boundaries : Array[Double],
) -> Array[Int] {
  if boundaries.is_empty() {
    abort("criticality boundaries must not be empty")
  }
  let sorted = boundaries.copy()
  sorted.sort()
  Array::makei(sorted.length() + 1, i => {
    let lower = if i == 0 { -1.0e300 } else { sorted[i - 1] }
    let upper = if i == sorted.length() { 1.0e300 } else { sorted[i] }
    observation.assets.fold(init=0, (count, asset) => {
      if asset.criticality >= lower && asset.criticality < upper {
        count + 1
      } else {
        count
      }
    })
  })
}

///|
pub fn fleet_failure_count_by_state(
  observation : FleetObservation,
) -> Array[Int] {
  [
    observation.assets.fold(init=0, (total, asset) => {
      if asset.state is FleetActive {
        total + asset.failure_count
      } else {
        total
      }
    }),
    observation.assets.fold(init=0, (total, asset) => {
      if asset.state is FleetFailed {
        total + asset.failure_count
      } else {
        total
      }
    }),
    observation.assets.fold(init=0, (total, asset) => {
      if asset.state is FleetMaintenance {
        total + asset.failure_count
      } else {
        total
      }
    }),
    observation.assets.fold(init=0, (total, asset) => {
      if asset.state is FleetRetired {
        total + asset.failure_count
      } else {
        total
      }
    }),
  ]
}

///|
pub fn fleet_failure_share_by_state(
  observation : FleetObservation,
) -> Array[Double] {
  let counts = fleet_failure_count_by_state(observation)
  let total = counts.fold(init=0, (sum, value) => sum + value)
  if total == 0 {
    counts.map(_ => 0.0)
  } else {
    counts.map(value => value.to_double() / total.to_double())
  }
}

///|
pub fn fleet_service_level(
  observation : FleetObservation,
  target_availability : Double,
) -> Double {
  if target_availability <= 0.0 || target_availability > 1.0 {
    abort("target availability must be in (0, 1]")
  }
  (fleet_weighted_availability(observation) / target_availability).min(1.0)
}

///|
pub fn fleet_service_level_label(value : Double) -> String {
  if value >= 1.0 {
    "met"
  } else if value >= 0.95 {
    "near-target"
  } else {
    "missed"
  }
}

///|
pub fn fleet_target_gap(
  observation : FleetObservation,
  target : Double,
) -> Double {
  (target - fleet_weighted_availability(observation)).max(0.0)
}

///|
pub fn fleet_expected_loss(
  observation : FleetObservation,
  horizon : Double,
  loss_per_failure : Double,
  loss_per_downtime_hour : Double,
) -> Double {
  if horizon < 0.0 || loss_per_failure < 0.0 || loss_per_downtime_hour < 0.0 {
    abort("invalid fleet loss inputs")
  }
  fleet_expected_failures(observation, horizon) * loss_per_failure +
  fleet_expected_downtime(observation, horizon) * loss_per_downtime_hour
}

///|
pub fn fleet_preventive_value(
  observation : FleetObservation,
  horizon : Double,
  preventive_cost : Double,
  avoided_failure_fraction : Double,
  loss_per_failure : Double,
) -> Double {
  if avoided_failure_fraction < 0.0 || avoided_failure_fraction > 1.0 {
    abort("avoided failure fraction must be in [0, 1]")
  }
  avoided_failure_fraction *
  fleet_expected_failures(observation, horizon) *
  loss_per_failure -
  preventive_cost
}

///|
pub fn fleet_replacement_value(
  asset : FleetAsset,
  remaining_horizon : Double,
  replacement_cost : Double,
  avoided_failure_fraction : Double,
  loss_per_failure : Double,
) -> Double {
  if remaining_horizon < 0.0 ||
    replacement_cost < 0.0 ||
    avoided_failure_fraction < 0.0 ||
    avoided_failure_fraction > 1.0 {
    abort("invalid replacement value inputs")
  }
  avoided_failure_fraction *
  fleet_asset_failure_rate(asset) *
  remaining_horizon *
  loss_per_failure -
  replacement_cost
}

///|
pub fn fleet_batch_expected_failures(
  observations : Array[FleetObservation],
  horizons : Array[Double],
) -> Array[Double] {
  if observations.length() != horizons.length() {
    abort("batch inputs must have the same length")
  }
  Array::makei(observations.length(), i => {
    fleet_expected_failures(observations[i], horizons[i])
  })
}

///|
pub fn fleet_batch_availability(
  observations : Array[FleetObservation],
) -> Array[Double] {
  observations.map(observation => fleet_weighted_availability(observation))
}

///|
pub fn fleet_batch_health(
  observations : Array[FleetObservation],
) -> Array[Double] {
  observations.map(observation => fleet_health_index(observation))
}

///|
pub fn fleet_batch_checksum(observations : Array[FleetObservation]) -> Double {
  observations.fold(init=0.0, (total, observation) => {
    total + fleet_snapshot_checksum(observation)
  })
}
