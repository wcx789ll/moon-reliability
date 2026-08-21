///|
/// Priority used by a maintenance control room when dispatching work.
pub(all) enum ResourceMaintenancePriority {
  ResourceEmergency
  ResourceUrgent
  ResourceRoutine
  ResourceDeferred
} derive(Debug, Eq)

///|
/// Lifecycle state of a maintenance work order.
pub(all) enum ResourceWorkOrderState {
  ResourcePlanned
  ResourceQueued
  ResourceAssigned
  ResourceInProgress
  ResourceCompleted
  ResourceBlocked
  ResourceCancelled
} derive(Debug, Eq)

///|
/// A schedulable maintenance work order with a measurable service target.
pub struct ResourceWorkOrder {
  work_id : Int
  asset_id : Int
  opened_at : Double
  due_at : Double
  estimated_hours : Double
  priority : ResourceMaintenancePriority
  state : ResourceWorkOrderState
  required_skill : String
  required_parts : Array[Int]
  consequence : Double
  customer_impact : Double
}

///|
pub fn resource_work_order(
  work_id : Int,
  asset_id : Int,
  opened_at : Double,
  due_at : Double,
  estimated_hours : Double,
  priority : ResourceMaintenancePriority,
  state : ResourceWorkOrderState,
  required_skill : String,
  required_parts : Array[Int],
  consequence : Double,
  customer_impact : Double,
) -> ResourceWorkOrder {
  if work_id < 0 ||
    asset_id < 0 ||
    due_at < opened_at ||
    estimated_hours <= 0.0 ||
    consequence < 0.0 ||
    customer_impact < 0.0 {
    abort("invalid resource work order")
  }
  for part in required_parts {
    if part < 0 {
      abort("part identifiers must be non-negative")
    }
  }
  {
    work_id,
    asset_id,
    opened_at,
    due_at,
    estimated_hours,
    priority,
    state,
    required_skill,
    required_parts,
    consequence,
    customer_impact,
  }
}

///|
pub fn resource_work_order_id(order : ResourceWorkOrder) -> Int {
  order.work_id
}

///|
pub fn resource_work_order_asset_id(order : ResourceWorkOrder) -> Int {
  order.asset_id
}

///|
pub fn resource_work_order_age(
  order : ResourceWorkOrder,
  now : Double,
) -> Double {
  (now - order.opened_at).max(0.0)
}

///|
pub fn resource_work_order_slack(
  order : ResourceWorkOrder,
  now : Double,
) -> Double {
  order.due_at - now
}

///|
pub fn resource_work_order_is_late(
  order : ResourceWorkOrder,
  now : Double,
) -> Bool {
  order.state != ResourceWorkOrderState::ResourceCompleted &&
  order.state != ResourceWorkOrderState::ResourceCancelled &&
  now > order.due_at
}

///|
pub fn resource_work_order_is_open(order : ResourceWorkOrder) -> Bool {
  order.state != ResourceWorkOrderState::ResourceCompleted &&
  order.state != ResourceWorkOrderState::ResourceCancelled
}

///|
pub fn resource_priority_weight(
  priority : ResourceMaintenancePriority,
) -> Double {
  match priority {
    ResourceMaintenancePriority::ResourceEmergency => 1.0
    ResourceMaintenancePriority::ResourceUrgent => 0.7
    ResourceMaintenancePriority::ResourceRoutine => 0.4
    ResourceMaintenancePriority::ResourceDeferred => 0.1
  }
}

///|
pub fn resource_work_order_score(
  order : ResourceWorkOrder,
  now : Double,
) -> Double {
  let lateness = if resource_work_order_is_late(order, now) {
    1.0 + (now - order.due_at).max(0.0)
  } else {
    1.0 / (1.0 + order.due_at - now)
  }
  resource_priority_weight(order.priority) *
  (1.0 + order.consequence) *
  (1.0 + order.customer_impact) *
  lateness
}

///|
pub fn resource_work_order_with_state(
  order : ResourceWorkOrder,
  state : ResourceWorkOrderState,
) -> ResourceWorkOrder {
  { ..order, state, }
}

///|
/// A maintenance crew with skill, shift, and utilization constraints.
pub struct ResourceCrew {
  crew_id : Int
  name : String
  skill : String
  shift_start : Double
  shift_end : Double
  capacity_hours : Double
  assigned_hours : Double
  hourly_cost : Double
  overtime_limit : Double
}

///|
pub fn resource_crew(
  crew_id : Int,
  name : String,
  skill : String,
  shift_start : Double,
  shift_end : Double,
  capacity_hours : Double,
  assigned_hours : Double,
  hourly_cost : Double,
  overtime_limit : Double,
) -> ResourceCrew {
  if crew_id < 0 ||
    shift_end < shift_start ||
    capacity_hours < 0.0 ||
    assigned_hours < 0.0 ||
    hourly_cost < 0.0 ||
    overtime_limit < 0.0 {
    abort("invalid resource crew")
  }
  {
    crew_id,
    name,
    skill,
    shift_start,
    shift_end,
    capacity_hours,
    assigned_hours,
    hourly_cost,
    overtime_limit,
  }
}

///|
pub fn resource_crew_id(crew : ResourceCrew) -> Int {
  crew.crew_id
}

///|
pub fn resource_crew_shift_hours(crew : ResourceCrew) -> Double {
  (crew.shift_end - crew.shift_start).max(0.0)
}

///|
pub fn resource_crew_available_hours(crew : ResourceCrew) -> Double {
  (crew.capacity_hours + crew.overtime_limit - crew.assigned_hours).max(0.0)
}

///|
pub fn resource_crew_utilization(crew : ResourceCrew) -> Double {
  if crew.capacity_hours <= 0.0 {
    0.0
  } else {
    crew.assigned_hours / crew.capacity_hours
  }
}

///|
pub fn resource_crew_can_accept(
  crew : ResourceCrew,
  order : ResourceWorkOrder,
  now : Double,
) -> Bool {
  crew.skill == order.required_skill &&
  resource_work_order_is_open(order) &&
  resource_crew_available_hours(crew) >= order.estimated_hours &&
  crew.shift_end >= now
}

///|
pub fn resource_crew_assign(
  crew : ResourceCrew,
  order : ResourceWorkOrder,
) -> ResourceCrew {
  if crew.skill != order.required_skill {
    abort("crew skill does not match work order")
  }
  if resource_crew_available_hours(crew) < order.estimated_hours {
    abort("crew has insufficient capacity")
  }
  { ..crew, assigned_hours: crew.assigned_hours + order.estimated_hours }
}

///|
pub fn resource_crew_release(
  crew : ResourceCrew,
  hours : Double,
) -> ResourceCrew {
  if hours < 0.0 {
    abort("released hours must be non-negative")
  }
  { ..crew, assigned_hours: (crew.assigned_hours - hours).max(0.0) }
}

///|
/// An inventory position for a service part.
pub struct ResourceSpare {
  part_id : Int
  on_hand : Int
  on_order : Int
  reserved : Int
  reorder_point : Int
  reorder_quantity : Int
  unit_cost : Double
  lead_time : Double
  criticality : Double
}

///|
pub fn resource_spare(
  part_id : Int,
  on_hand : Int,
  on_order : Int,
  reserved : Int,
  reorder_point : Int,
  reorder_quantity : Int,
  unit_cost : Double,
  lead_time : Double,
  criticality : Double,
) -> ResourceSpare {
  if part_id < 0 ||
    on_hand < 0 ||
    on_order < 0 ||
    reserved < 0 ||
    reorder_point < 0 ||
    reorder_quantity < 1 ||
    unit_cost < 0.0 ||
    lead_time < 0.0 ||
    criticality < 0.0 {
    abort("invalid resource spare")
  }
  {
    part_id,
    on_hand,
    on_order,
    reserved,
    reorder_point,
    reorder_quantity,
    unit_cost,
    lead_time,
    criticality,
  }
}

///|
pub fn resource_spare_id(spare : ResourceSpare) -> Int {
  spare.part_id
}

///|
pub fn resource_spare_available(spare : ResourceSpare) -> Int {
  (spare.on_hand - spare.reserved).max(0)
}

///|
pub fn resource_spare_inventory_position(spare : ResourceSpare) -> Int {
  spare.on_hand + spare.on_order - spare.reserved
}

///|
pub fn resource_spare_shortage(spare : ResourceSpare, demand : Int) -> Int {
  (demand - resource_spare_available(spare)).max(0)
}

///|
pub fn resource_spare_needs_reorder(spare : ResourceSpare) -> Bool {
  resource_spare_inventory_position(spare) <= spare.reorder_point
}

///|
pub fn resource_spare_reserve(
  spare : ResourceSpare,
  quantity : Int,
) -> ResourceSpare {
  if quantity < 0 || resource_spare_available(spare) < quantity {
    abort("insufficient spare availability")
  }
  { ..spare, reserved: spare.reserved + quantity }
}

///|
pub fn resource_spare_consume(
  spare : ResourceSpare,
  quantity : Int,
) -> ResourceSpare {
  if quantity < 0 || spare.on_hand < quantity {
    abort("insufficient spare stock")
  }
  {
    ..spare,
    on_hand: spare.on_hand - quantity,
    reserved: (spare.reserved - quantity).max(0),
  }
}

///|
pub fn resource_spare_receive(
  spare : ResourceSpare,
  quantity : Int,
) -> ResourceSpare {
  if quantity < 0 {
    abort("received quantity must be non-negative")
  }
  {
    ..spare,
    on_hand: spare.on_hand + quantity,
    on_order: (spare.on_order - quantity).max(0),
  }
}

///|
pub fn resource_spare_order_quantity(spare : ResourceSpare) -> Int {
  if resource_spare_needs_reorder(spare) {
    spare.reorder_quantity
  } else {
    0
  }
}

///|
pub fn resource_spare_expected_stock_cost(spare : ResourceSpare) -> Double {
  resource_spare_inventory_position(spare).to_double() * spare.unit_cost
}

///|
/// A scheduled time window for a crew and a set of work orders.
pub struct ResourceWindow {
  window_id : Int
  start : Double
  end : Double
  crew_id : Int
  order_ids : Array[Int]
  planned_hours : Double
}

///|
pub fn resource_window(
  window_id : Int,
  start : Double,
  end : Double,
  crew_id : Int,
  order_ids : Array[Int],
  planned_hours : Double,
) -> ResourceWindow {
  if window_id < 0 || end <= start || crew_id < 0 || planned_hours < 0.0 {
    abort("invalid maintenance window")
  }
  { window_id, start, end, crew_id, order_ids, planned_hours }
}

///|
pub fn resource_window_duration(window : ResourceWindow) -> Double {
  window.end - window.start
}

///|
pub fn resource_window_slack(window : ResourceWindow) -> Double {
  resource_window_duration(window) - window.planned_hours
}

///|
pub fn resource_window_is_overloaded(window : ResourceWindow) -> Bool {
  resource_window_slack(window) < 0.0
}

///|
pub fn resource_window_utilization(window : ResourceWindow) -> Double {
  if resource_window_duration(window) <= 0.0 {
    0.0
  } else {
    window.planned_hours / resource_window_duration(window)
  }
}

///|
pub fn resource_window_add_order(
  window : ResourceWindow,
  order : ResourceWorkOrder,
) -> ResourceWindow {
  if window.crew_id < 0 {
    abort("invalid crew in maintenance window")
  }
  let order_ids = window.order_ids.copy()
  order_ids.push(order.work_id)
  {
    ..window,
    order_ids,
    planned_hours: window.planned_hours + order.estimated_hours,
  }
}

///|
/// A dispatch result that records why work was accepted or held.
pub struct ResourceDispatch {
  order_id : Int
  crew_id : Int
  part_ids : Array[Int]
  accepted : Bool
  reason : String
  completion_time : Double
  direct_cost : Double
  shortage_cost : Double
}

///|
pub fn resource_dispatch(
  order_id : Int,
  crew_id : Int,
  part_ids : Array[Int],
  accepted : Bool,
  reason : String,
  completion_time : Double,
  direct_cost : Double,
  shortage_cost : Double,
) -> ResourceDispatch {
  if order_id < 0 ||
    crew_id < 0 ||
    completion_time < 0.0 ||
    direct_cost < 0.0 ||
    shortage_cost < 0.0 {
    abort("invalid dispatch result")
  }
  {
    order_id,
    crew_id,
    part_ids,
    accepted,
    reason,
    completion_time,
    direct_cost,
    shortage_cost,
  }
}

///|
pub fn resource_dispatch_total_cost(dispatch : ResourceDispatch) -> Double {
  dispatch.direct_cost + dispatch.shortage_cost
}

///|
pub fn resource_dispatch_success_rate(
  dispatches : Array[ResourceDispatch],
) -> Double {
  if dispatches.is_empty() {
    0.0
  } else {
    let accepted = dispatches.fold(init=0, (count, item) => {
      if item.accepted {
        count + 1
      } else {
        count
      }
    })
    accepted.to_double() / dispatches.length().to_double()
  }
}

///|
pub fn resource_dispatch_average_cost(
  dispatches : Array[ResourceDispatch],
) -> Double {
  if dispatches.is_empty() {
    0.0
  } else {
    dispatches.fold(init=0.0, (sum, item) => {
      sum + resource_dispatch_total_cost(item)
    }) /
    dispatches.length().to_double()
  }
}

///|
/// Aggregate resource status for a planning horizon.
pub struct ResourceSnapshot {
  now : Double
  open_orders : Int
  late_orders : Int
  crew_hours : Double
  available_hours : Double
  spare_value : Double
  shortage_units : Int
  backlog_hours : Double
  service_level : Double
}

///|
pub fn resource_snapshot(
  now : Double,
  orders : Array[ResourceWorkOrder],
  crews : Array[ResourceCrew],
  spares : Array[ResourceSpare],
) -> ResourceSnapshot {
  let open_orders = orders.fold(init=0, (count, order) => {
    if resource_work_order_is_open(order) {
      count + 1
    } else {
      count
    }
  })
  let late_orders = orders.fold(init=0, (count, order) => {
    if resource_work_order_is_late(order, now) {
      count + 1
    } else {
      count
    }
  })
  let backlog_hours = orders.fold(init=0.0, (sum, order) => {
    if resource_work_order_is_open(order) {
      sum + order.estimated_hours
    } else {
      sum
    }
  })
  let crew_hours = crews.fold(init=0.0, (sum, crew) => sum + crew.capacity_hours)
  let available_hours = crews.fold(init=0.0, (sum, crew) => {
    sum + resource_crew_available_hours(crew)
  })
  let spare_value = spares.fold(init=0.0, (sum, spare) => {
    sum + resource_spare_expected_stock_cost(spare)
  })
  let shortage_units = spares.fold(init=0, (sum, spare) => {
    sum + resource_spare_shortage(spare, spare.reorder_point)
  })
  let service_level = if open_orders == 0 {
    1.0
  } else {
    (open_orders - late_orders).to_double() / open_orders.to_double()
  }
  {
    now,
    open_orders,
    late_orders,
    crew_hours,
    available_hours,
    spare_value,
    shortage_units,
    backlog_hours,
    service_level,
  }
}

///|
pub fn resource_snapshot_capacity_ratio(snapshot : ResourceSnapshot) -> Double {
  if snapshot.backlog_hours <= 0.0 {
    1.0
  } else {
    snapshot.available_hours / snapshot.backlog_hours
  }
}

///|
pub fn resource_snapshot_health(snapshot : ResourceSnapshot) -> Double {
  let capacity = resource_snapshot_capacity_ratio(snapshot).min(1.0)
  let stock = if snapshot.spare_value <= 0.0 {
    1.0
  } else {
    1.0 / (1.0 + snapshot.shortage_units.to_double())
  }
  (snapshot.service_level.max(0.0) * capacity * stock).max(0.0).min(1.0)
}

///|
pub fn resource_orders_by_priority(
  orders : Array[ResourceWorkOrder],
  now : Double,
) -> Array[ResourceWorkOrder] {
  let result = orders.copy()
  result.sort_by((left, right) => {
    let left_score = resource_work_order_score(left, now)
    let right_score = resource_work_order_score(right, now)
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
pub fn resource_open_order_ids(orders : Array[ResourceWorkOrder]) -> Array[Int] {
  orders.filter_map(order => {
    if resource_work_order_is_open(order) {
      Some(order.work_id)
    } else {
      None
    }
  })
}

///|
pub fn resource_late_order_ids(
  orders : Array[ResourceWorkOrder],
  now : Double,
) -> Array[Int] {
  orders.filter_map(order => {
    if resource_work_order_is_late(order, now) {
      Some(order.work_id)
    } else {
      None
    }
  })
}

///|
pub fn resource_skill_demand(
  orders : Array[ResourceWorkOrder],
  skill : String,
) -> Double {
  orders.fold(init=0.0, (sum, order) => {
    if resource_work_order_is_open(order) && order.required_skill == skill {
      sum + order.estimated_hours
    } else {
      sum
    }
  })
}

///|
pub fn resource_part_demand(
  orders : Array[ResourceWorkOrder],
  part_id : Int,
) -> Int {
  orders.fold(init=0, (sum, order) => {
    if resource_work_order_is_open(order) {
      sum +
      order.required_parts.fold(init=0, (count, part) => {
        if part == part_id {
          count + 1
        } else {
          count
        }
      })
    } else {
      sum
    }
  })
}

///|
pub fn resource_crew_match(
  orders : Array[ResourceWorkOrder],
  crew : ResourceCrew,
  now : Double,
) -> Array[Int] {
  let mut hours = resource_crew_available_hours(crew)
  let result = Array::new()
  for order in resource_orders_by_priority(orders, now) {
    if resource_work_order_is_open(order) &&
      order.required_skill == crew.skill &&
      hours >= order.estimated_hours {
      result.push(order.work_id)
      hours -= order.estimated_hours
    }
  }
  result
}

///|
pub fn resource_backlog_cost(
  orders : Array[ResourceWorkOrder],
  crews : Array[ResourceCrew],
  now : Double,
  penalty_per_hour : Double,
) -> Double {
  if penalty_per_hour < 0.0 {
    abort("backlog penalty must be non-negative")
  }
  let labor = crews.fold(init=0.0, (sum, crew) => {
    sum + crew.assigned_hours * crew.hourly_cost
  })
  let penalty = orders.fold(init=0.0, (sum, order) => {
    if resource_work_order_is_late(order, now) {
      sum + (now - order.due_at) * penalty_per_hour
    } else {
      sum
    }
  })
  labor + penalty
}

///|
pub fn resource_sla_breach_count(
  orders : Array[ResourceWorkOrder],
  now : Double,
) -> Int {
  orders.fold(init=0, (count, order) => {
    if resource_work_order_is_late(order, now) {
      count + 1
    } else {
      count
    }
  })
}

///|
pub fn resource_sla_breach_fraction(
  orders : Array[ResourceWorkOrder],
  now : Double,
) -> Double {
  if orders.is_empty() {
    0.0
  } else {
    resource_sla_breach_count(orders, now).to_double() /
    orders.length().to_double()
  }
}

///|
pub fn resource_planning_checksum(snapshot : ResourceSnapshot) -> Double {
  snapshot.now +
  snapshot.open_orders.to_double() * 3.0 +
  snapshot.late_orders.to_double() * 5.0 +
  snapshot.available_hours +
  snapshot.spare_value * 0.01 +
  snapshot.backlog_hours +
  snapshot.service_level
}
