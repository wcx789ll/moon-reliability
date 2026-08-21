///|
/// Lifecycle state for an asset service case.
pub(all) enum ReliabilityServiceCaseState {
  ReliabilityCaseNew
  ReliabilityCaseTriaged
  ReliabilityCaseDispatched
  ReliabilityCaseOnSite
  ReliabilityCaseWaitingPart
  ReliabilityCaseResolved
  ReliabilityCaseClosed
} derive(Debug, Eq)

///|
/// Urgency used by a field service dispatch center.
pub(all) enum ReliabilityServiceUrgency {
  ReliabilityServiceCritical
  ReliabilityServiceHigh
  ReliabilityServiceNormal
  ReliabilityServiceLow
} derive(Debug, Eq)

///|
/// A customer-visible service case linked to a reliability event.
pub struct ReliabilityServiceCase {
  case_id : String
  asset_id : Int
  opened_at : Double
  promised_at : Double
  state : ReliabilityServiceCaseState
  urgency : ReliabilityServiceUrgency
  symptom_code : String
  estimated_hours : Double
  customer_impact : Double
  repeat_failure : Bool
  warranty_covered : Bool
}

///|
pub fn reliability_service_case(
  case_id : String,
  asset_id : Int,
  opened_at : Double,
  promised_at : Double,
  state : ReliabilityServiceCaseState,
  urgency : ReliabilityServiceUrgency,
  symptom_code : String,
  estimated_hours : Double,
  customer_impact : Double,
  repeat_failure : Bool,
  warranty_covered : Bool,
) -> ReliabilityServiceCase {
  if asset_id < 0 ||
    opened_at < 0.0 ||
    promised_at < opened_at ||
    estimated_hours < 0.0 ||
    customer_impact < 0.0 {
    abort("invalid service case")
  }
  {
    case_id,
    asset_id,
    opened_at,
    promised_at,
    state,
    urgency,
    symptom_code,
    estimated_hours,
    customer_impact,
    repeat_failure,
    warranty_covered,
  }
}

///|
pub fn reliability_service_case_is_open(case : ReliabilityServiceCase) -> Bool {
  case.state != ReliabilityServiceCaseState::ReliabilityCaseClosed &&
  case.state != ReliabilityServiceCaseState::ReliabilityCaseResolved
}

///|
pub fn reliability_service_case_is_late(
  case : ReliabilityServiceCase,
  as_of : Double,
) -> Bool {
  reliability_service_case_is_open(case) && as_of > case.promised_at
}

///|
pub fn reliability_service_case_age(
  case : ReliabilityServiceCase,
  as_of : Double,
) -> Double {
  (as_of - case.opened_at).max(0.0)
}

///|
pub fn reliability_service_case_slack(
  case : ReliabilityServiceCase,
  as_of : Double,
) -> Double {
  case.promised_at - as_of
}

///|
pub fn reliability_service_urgency_weight(
  urgency : ReliabilityServiceUrgency,
) -> Double {
  match urgency {
    ReliabilityServiceCritical => 1.0
    ReliabilityServiceHigh => 0.7
    ReliabilityServiceNormal => 0.4
    ReliabilityServiceLow => 0.1
  }
}

///|
pub fn reliability_service_case_priority(
  case : ReliabilityServiceCase,
  as_of : Double,
) -> Double {
  let lateness = if reliability_service_case_is_late(case, as_of) {
    1.0 + (as_of - case.promised_at)
  } else {
    1.0 / (1.0 + case.promised_at - as_of)
  }
  reliability_service_urgency_weight(case.urgency) *
  (1.0 + case.customer_impact) *
  (if case.repeat_failure { 1.5 } else { 1.0 }) *
  lateness
}

///|
pub fn reliability_service_case_with_state(
  case : ReliabilityServiceCase,
  state : ReliabilityServiceCaseState,
) -> ReliabilityServiceCase {
  { ..case, state, }
}

///|
/// A field technician's shift, skill, and travel capacity.
pub struct ReliabilityTechnician {
  technician_id : String
  name : String
  skill : String
  home_latitude : Double
  home_longitude : Double
  shift_start : Double
  shift_end : Double
  available_hours : Double
  hourly_cost : Double
  enabled : Bool
}

///|
pub fn reliability_technician(
  technician_id : String,
  name : String,
  skill : String,
  home_latitude : Double,
  home_longitude : Double,
  shift_start : Double,
  shift_end : Double,
  available_hours : Double,
  hourly_cost : Double,
  enabled : Bool,
) -> ReliabilityTechnician {
  if shift_start < 0.0 ||
    shift_end < shift_start ||
    available_hours < 0.0 ||
    hourly_cost < 0.0 {
    abort("invalid field technician")
  }
  {
    technician_id,
    name,
    skill,
    home_latitude,
    home_longitude,
    shift_start,
    shift_end,
    available_hours,
    hourly_cost,
    enabled,
  }
}

///|
pub fn reliability_technician_shift_hours(
  technician : ReliabilityTechnician,
) -> Double {
  technician.shift_end - technician.shift_start
}

///|
pub fn reliability_technician_utilization(
  technician : ReliabilityTechnician,
  assigned_hours : Double,
) -> Double {
  if technician.available_hours == 0.0 {
    0.0
  } else {
    assigned_hours / technician.available_hours
  }
}

///|
pub fn reliability_technician_can_take(
  technician : ReliabilityTechnician,
  required_skill : String,
  hours : Double,
) -> Bool {
  technician.enabled &&
  technician.skill == required_skill &&
  hours >= 0.0 &&
  technician.available_hours >= hours
}

///|
pub fn reliability_technician_after_assignment(
  technician : ReliabilityTechnician,
  hours : Double,
) -> ReliabilityTechnician {
  if hours < 0.0 || hours > technician.available_hours {
    abort("technician capacity exceeded")
  }
  { ..technician, available_hours: technician.available_hours - hours }
}

///|
/// A planned or completed service visit.
pub struct ReliabilityServiceVisit {
  visit_id : String
  case_id : String
  technician_id : String
  scheduled_at : Double
  arrival_at : Double
  departure_at : Double
  travel_hours : Double
  work_hours : Double
  distance : Double
  successful : Bool
  notes_quality : Double
}

///|
pub fn reliability_service_visit(
  visit_id : String,
  case_id : String,
  technician_id : String,
  scheduled_at : Double,
  arrival_at : Double,
  departure_at : Double,
  travel_hours : Double,
  work_hours : Double,
  distance : Double,
  successful : Bool,
  notes_quality : Double,
) -> ReliabilityServiceVisit {
  if scheduled_at < 0.0 ||
    arrival_at < scheduled_at ||
    departure_at < arrival_at ||
    travel_hours < 0.0 ||
    work_hours < 0.0 ||
    distance < 0.0 ||
    notes_quality < 0.0 ||
    notes_quality > 1.0 {
    abort("invalid service visit")
  }
  {
    visit_id,
    case_id,
    technician_id,
    scheduled_at,
    arrival_at,
    departure_at,
    travel_hours,
    work_hours,
    distance,
    successful,
    notes_quality,
  }
}

///|
pub fn reliability_service_visit_response_time(
  visit : ReliabilityServiceVisit,
) -> Double {
  visit.arrival_at - visit.scheduled_at
}

///|
pub fn reliability_service_visit_duration(
  visit : ReliabilityServiceVisit,
) -> Double {
  visit.departure_at - visit.arrival_at
}

///|
pub fn reliability_service_visit_cycle_time(
  visit : ReliabilityServiceVisit,
) -> Double {
  visit.departure_at - visit.scheduled_at
}

///|
pub fn reliability_service_visit_productivity(
  visit : ReliabilityServiceVisit,
) -> Double {
  let total = reliability_service_visit_cycle_time(visit)
  if total == 0.0 {
    0.0
  } else {
    visit.work_hours / total
  }
}

///|
pub fn reliability_service_visit_is_late(
  visit : ReliabilityServiceVisit,
  promised_at : Double,
) -> Bool {
  visit.departure_at > promised_at
}

///|
pub fn reliability_service_visit_cost(
  visit : ReliabilityServiceVisit,
  technician : ReliabilityTechnician,
  travel_rate : Double,
) -> Double {
  if travel_rate < 0.0 {
    abort("travel rate must be non-negative")
  }
  (visit.work_hours + visit.travel_hours) * technician.hourly_cost +
  visit.distance * travel_rate
}

///|
/// Parts consumed during service and the resulting cost.
pub struct ReliabilityServicePartUse {
  case_id : String
  part_id : Int
  quantity : Int
  unit_cost : Double
  returned : Int
  stockout : Bool
}

///|
pub fn reliability_service_part_use(
  case_id : String,
  part_id : Int,
  quantity : Int,
  unit_cost : Double,
  returned : Int,
  stockout : Bool,
) -> ReliabilityServicePartUse {
  if part_id < 0 ||
    quantity < 0 ||
    unit_cost < 0.0 ||
    returned < 0 ||
    returned > quantity {
    abort("invalid service part use")
  }
  { case_id, part_id, quantity, unit_cost, returned, stockout }
}

///|
pub fn reliability_service_part_net_quantity(
  use_record : ReliabilityServicePartUse,
) -> Int {
  use_record.quantity - use_record.returned
}

///|
pub fn reliability_service_part_cost(
  use_record : ReliabilityServicePartUse,
) -> Double {
  reliability_service_part_net_quantity(use_record).to_double() *
  use_record.unit_cost
}

///|
pub fn reliability_service_part_is_shortage(
  use_record : ReliabilityServicePartUse,
) -> Bool {
  use_record.stockout
}

///|
pub fn reliability_service_case_parts_cost(
  uses : Array[ReliabilityServicePartUse],
  case_id : String,
) -> Double {
  uses.fold(init=0.0, (sum, use_record) => {
    if use_record.case_id == case_id {
      sum + reliability_service_part_cost(use_record)
    } else {
      sum
    }
  })
}

///|
/// Service-level agreement thresholds for response and restoration.
pub struct ReliabilityServiceSla {
  sla_id : String
  response_target : Double
  restoration_target : Double
  target_fraction : Double
  penalty_per_hour : Double
  critical_multiplier : Double
}

///|
pub fn reliability_service_sla(
  sla_id : String,
  response_target : Double,
  restoration_target : Double,
  target_fraction : Double,
  penalty_per_hour : Double,
  critical_multiplier : Double,
) -> ReliabilityServiceSla {
  if response_target < 0.0 ||
    restoration_target < 0.0 ||
    target_fraction < 0.0 ||
    target_fraction > 1.0 ||
    penalty_per_hour < 0.0 ||
    critical_multiplier < 0.0 {
    abort("invalid service SLA")
  }
  {
    sla_id,
    response_target,
    restoration_target,
    target_fraction,
    penalty_per_hour,
    critical_multiplier,
  }
}

///|
pub fn reliability_service_sla_response_passes(
  sla : ReliabilityServiceSla,
  visit : ReliabilityServiceVisit,
) -> Bool {
  reliability_service_visit_response_time(visit) <= sla.response_target
}

///|
pub fn reliability_service_sla_restoration_passes(
  sla : ReliabilityServiceSla,
  visit : ReliabilityServiceVisit,
) -> Bool {
  reliability_service_visit_cycle_time(visit) <= sla.restoration_target
}

///|
pub fn reliability_service_sla_penalty(
  sla : ReliabilityServiceSla,
  visit : ReliabilityServiceVisit,
  critical : Bool,
) -> Double {
  let response_over = (reliability_service_visit_response_time(visit) -
  sla.response_target).max(0.0)
  let restoration_over = (reliability_service_visit_cycle_time(visit) -
  sla.restoration_target).max(0.0)
  let multiplier = if critical { sla.critical_multiplier } else { 1.0 }
  (response_over + restoration_over) * sla.penalty_per_hour * multiplier
}

///|
pub fn reliability_service_sla_compliant_fraction(
  sla : ReliabilityServiceSla,
  visits : Array[ReliabilityServiceVisit],
) -> Double {
  if visits.is_empty() {
    1.0
  } else {
    visits
    .fold(init=0, (count, visit) => {
      if reliability_service_sla_response_passes(sla, visit) &&
        reliability_service_sla_restoration_passes(sla, visit) {
        count + 1
      } else {
        count
      }
    })
    .to_double() /
    visits.length().to_double()
  }
}

///|
pub fn reliability_service_sla_is_met(
  sla : ReliabilityServiceSla,
  visits : Array[ReliabilityServiceVisit],
) -> Bool {
  reliability_service_sla_compliant_fraction(sla, visits) >= sla.target_fraction
}

///|
/// Resolution outcome used for continuous improvement of service procedures.
pub struct ReliabilityServiceOutcome {
  case_id : String
  root_cause : String
  corrective_action : String
  verified : Bool
  customer_satisfied : Bool
  repeat_within_window : Bool
  downtime : Double
  total_cost : Double
  learning_value : Double
}

///|
pub fn reliability_service_outcome(
  case_id : String,
  root_cause : String,
  corrective_action : String,
  verified : Bool,
  customer_satisfied : Bool,
  repeat_within_window : Bool,
  downtime : Double,
  total_cost : Double,
  learning_value : Double,
) -> ReliabilityServiceOutcome {
  if downtime < 0.0 || total_cost < 0.0 || learning_value < 0.0 {
    abort("invalid service outcome")
  }
  {
    case_id,
    root_cause,
    corrective_action,
    verified,
    customer_satisfied,
    repeat_within_window,
    downtime,
    total_cost,
    learning_value,
  }
}

///|
pub fn reliability_service_outcome_effective(
  outcome : ReliabilityServiceOutcome,
) -> Bool {
  outcome.verified &&
  outcome.customer_satisfied &&
  !outcome.repeat_within_window
}

///|
pub fn reliability_service_outcome_quality(
  outcome : ReliabilityServiceOutcome,
) -> Double {
  let verification = if outcome.verified { 0.4 } else { 0.0 }
  let satisfaction = if outcome.customer_satisfied { 0.3 } else { 0.0 }
  let repeat = if outcome.repeat_within_window { 0.0 } else { 0.3 }
  verification + satisfaction + repeat
}

///|
pub fn reliability_service_outcome_cost_per_downtime_hour(
  outcome : ReliabilityServiceOutcome,
) -> Double {
  if outcome.downtime == 0.0 {
    outcome.total_cost
  } else {
    outcome.total_cost / outcome.downtime
  }
}

///|
/// Operational service summary for a period.
pub struct ReliabilityServiceSummary {
  case_count : Int
  open_count : Int
  late_count : Int
  visit_count : Int
  successful_visits : Int
  repeat_count : Int
  average_response : Double
  average_cycle : Double
  total_cost : Double
  total_downtime : Double
  sla_fraction : Double
  first_time_fix_rate : Double
}

///|
pub fn reliability_service_summary(
  as_of : Double,
  cases : Array[ReliabilityServiceCase],
  visits : Array[ReliabilityServiceVisit],
  outcomes : Array[ReliabilityServiceOutcome],
  sla : ReliabilityServiceSla,
) -> ReliabilityServiceSummary {
  let open = cases
    .filter(case => reliability_service_case_is_open(case))
    .length()
  let late = cases
    .filter(case => reliability_service_case_is_late(case, as_of))
    .length()
  let successful = visits.filter(visit => visit.successful).length()
  let response = if visits.is_empty() {
    0.0
  } else {
    visits.fold(init=0.0, (sum, visit) => {
      sum + reliability_service_visit_response_time(visit)
    }) /
    visits.length().to_double()
  }
  let cycle = if visits.is_empty() {
    0.0
  } else {
    visits.fold(init=0.0, (sum, visit) => {
      sum + reliability_service_visit_cycle_time(visit)
    }) /
    visits.length().to_double()
  }
  let cost = outcomes.fold(init=0.0, (sum, outcome) => sum + outcome.total_cost)
  let downtime = outcomes.fold(init=0.0, (sum, outcome) => {
    sum + outcome.downtime
  })
  let repeats = outcomes
    .filter(outcome => outcome.repeat_within_window)
    .length()
  let first_fix = if visits.is_empty() {
    0.0
  } else {
    successful.to_double() / visits.length().to_double()
  }
  {
    case_count: cases.length(),
    open_count: open,
    late_count: late,
    visit_count: visits.length(),
    successful_visits: successful,
    repeat_count: repeats,
    average_response: response,
    average_cycle: cycle,
    total_cost: cost,
    total_downtime: downtime,
    sla_fraction: reliability_service_sla_compliant_fraction(sla, visits),
    first_time_fix_rate: first_fix,
  }
}

///|
pub fn reliability_service_summary_readiness(
  summary : ReliabilityServiceSummary,
) -> Double {
  let response = if summary.average_response == 0.0 {
    1.0
  } else {
    1.0 / (1.0 + summary.average_response)
  }
  let repeat = if summary.visit_count == 0 {
    1.0
  } else {
    1.0 - summary.repeat_count.to_double() / summary.visit_count.to_double()
  }
  (0.35 * summary.sla_fraction +
  0.35 * summary.first_time_fix_rate +
  0.2 * repeat +
  0.1 * response)
  .min(1.0)
  .max(0.0)
}

///|
pub fn reliability_service_case_ranked(
  cases : Array[ReliabilityServiceCase],
  as_of : Double,
) -> Array[ReliabilityServiceCase] {
  let result = cases.copy()
  result.sort_by((left, right) => {
    let a = reliability_service_case_priority(left, as_of)
    let b = reliability_service_case_priority(right, as_of)
    if a > b {
      -1
    } else if a < b {
      1
    } else {
      0
    }
  })
  result
}

///|
pub fn reliability_service_symptom_count(
  cases : Array[ReliabilityServiceCase],
  symptom_code : String,
) -> Int {
  cases.fold(init=0, (count, case) => {
    if case.symptom_code == symptom_code {
      count + 1
    } else {
      count
    }
  })
}

///|
pub fn reliability_service_asset_case_count(
  cases : Array[ReliabilityServiceCase],
  asset_id : Int,
) -> Int {
  cases.fold(init=0, (count, case) => {
    if case.asset_id == asset_id {
      count + 1
    } else {
      count
    }
  })
}

///|
pub fn reliability_service_warranty_fraction(
  cases : Array[ReliabilityServiceCase],
) -> Double {
  if cases.is_empty() {
    0.0
  } else {
    cases.filter(case => case.warranty_covered).length().to_double() /
    cases.length().to_double()
  }
}

///|
pub fn reliability_service_repeat_fraction(
  cases : Array[ReliabilityServiceCase],
) -> Double {
  if cases.is_empty() {
    0.0
  } else {
    cases.filter(case => case.repeat_failure).length().to_double() /
    cases.length().to_double()
  }
}

///|
pub fn reliability_service_dispatch_match(
  case : ReliabilityServiceCase,
  technicians : Array[ReliabilityTechnician],
  required_skill : String,
) -> Int {
  let mut best = -1
  let mut best_capacity = -1.0
  for i in 0..<technicians.length() {
    let technician = technicians[i]
    if reliability_technician_can_take(
        technician,
        required_skill,
        case.estimated_hours,
      ) &&
      technician.available_hours > best_capacity {
      best = i
      best_capacity = technician.available_hours
    }
  }
  best
}

///|
pub fn reliability_service_total_visit_cost(
  visits : Array[ReliabilityServiceVisit],
  technicians : Array[ReliabilityTechnician],
  travel_rate : Double,
) -> Double {
  visits.fold(init=0.0, (sum, visit) => {
    let technician = technicians.filter_map(item => {
      if item.technician_id == visit.technician_id {
        Some(item)
      } else {
        None
      }
    })
    if technician.is_empty() {
      sum
    } else {
      sum + reliability_service_visit_cost(visit, technician[0], travel_rate)
    }
  })
}

///|
pub fn reliability_service_checksum(
  summary : ReliabilityServiceSummary,
) -> Double {
  summary.case_count.to_double() +
  summary.visit_count.to_double() * 2.0 +
  summary.total_cost +
  summary.total_downtime +
  summary.sla_fraction * 100.0 +
  summary.first_time_fix_rate * 10.0
}

///|
pub fn reliability_service_case_state_label(
  state : ReliabilityServiceCaseState,
) -> String {
  match state {
    ReliabilityCaseNew => "new"
    ReliabilityCaseTriaged => "triaged"
    ReliabilityCaseDispatched => "dispatched"
    ReliabilityCaseOnSite => "on_site"
    ReliabilityCaseWaitingPart => "waiting_part"
    ReliabilityCaseResolved => "resolved"
    ReliabilityCaseClosed => "closed"
  }
}

///|
pub fn reliability_service_critical_count(
  cases : Array[ReliabilityServiceCase],
) -> Int {
  cases.fold(init=0, (count, case) => {
    if case.urgency is ReliabilityServiceCritical {
      count + 1
    } else {
      count
    }
  })
}

///|
pub fn reliability_service_visit_success_fraction(
  visits : Array[ReliabilityServiceVisit],
) -> Double {
  if visits.is_empty() {
    0.0
  } else {
    visits.filter(visit => visit.successful).length().to_double() /
    visits.length().to_double()
  }
}

///|
pub fn reliability_service_verified_fraction(
  outcomes : Array[ReliabilityServiceOutcome],
) -> Double {
  if outcomes.is_empty() {
    0.0
  } else {
    outcomes.filter(outcome => outcome.verified).length().to_double() /
    outcomes.length().to_double()
  }
}

///|
pub fn reliability_service_customer_satisfaction(
  outcomes : Array[ReliabilityServiceOutcome],
) -> Double {
  if outcomes.is_empty() {
    0.0
  } else {
    outcomes.filter(outcome => outcome.customer_satisfied).length().to_double() /
    outcomes.length().to_double()
  }
}

///|
pub fn reliability_service_summary_cost_per_case(
  summary : ReliabilityServiceSummary,
) -> Double {
  if summary.case_count == 0 {
    0.0
  } else {
    summary.total_cost / summary.case_count.to_double()
  }
}

///|
pub fn reliability_service_summary_late_fraction(
  summary : ReliabilityServiceSummary,
) -> Double {
  if summary.case_count == 0 {
    0.0
  } else {
    summary.late_count.to_double() / summary.case_count.to_double()
  }
}

///|
pub fn reliability_service_summary_repeat_fraction(
  summary : ReliabilityServiceSummary,
) -> Double {
  if summary.visit_count == 0 {
    0.0
  } else {
    summary.repeat_count.to_double() / summary.visit_count.to_double()
  }
}

///|
pub fn reliability_service_visit_distance_per_hour(
  visit : ReliabilityServiceVisit,
) -> Double {
  if visit.travel_hours == 0.0 {
    visit.distance
  } else {
    visit.distance / visit.travel_hours
  }
}

///|
pub fn reliability_service_dispatch_capacity(
  technicians : Array[ReliabilityTechnician],
) -> Double {
  technicians.fold(init=0.0, (sum, technician) => {
    if technician.enabled {
      sum + technician.available_hours
    } else {
      sum
    }
  })
}
