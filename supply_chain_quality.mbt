///|
/// Supplier risk tier used to set incoming inspection intensity.
pub(all) enum SupplierRiskTier {
  SupplierApproved
  SupplierMonitored
  SupplierRestricted
  SupplierDisqualified
} derive(Debug, Eq)

///|
/// Supplier master record with quality, delivery, and continuity indicators.
pub struct ReliabilitySupplier {
  supplier_id : String
  name : String
  tier : SupplierRiskTier
  quality_ppm : Double
  on_time_rate : Double
  audit_score : Double
  lead_time : Double
  lead_time_variability : Double
  annual_spend : Double
  single_source : Bool
}

///|
pub fn reliability_supplier(
  supplier_id : String,
  name : String,
  tier : SupplierRiskTier,
  quality_ppm : Double,
  on_time_rate : Double,
  audit_score : Double,
  lead_time : Double,
  lead_time_variability : Double,
  annual_spend : Double,
  single_source : Bool,
) -> ReliabilitySupplier {
  if quality_ppm < 0.0 ||
    on_time_rate < 0.0 ||
    on_time_rate > 1.0 ||
    audit_score < 0.0 ||
    audit_score > 1.0 ||
    lead_time < 0.0 ||
    lead_time_variability < 0.0 ||
    annual_spend < 0.0 {
    abort("invalid supplier record")
  }
  {
    supplier_id,
    name,
    tier,
    quality_ppm,
    on_time_rate,
    audit_score,
    lead_time,
    lead_time_variability,
    annual_spend,
    single_source,
  }
}

///|
pub fn reliability_supplier_quality_rate(
  supplier : ReliabilitySupplier,
) -> Double {
  1.0 / (1.0 + supplier.quality_ppm / 1000.0)
}

///|
pub fn reliability_supplier_delivery_score(
  supplier : ReliabilitySupplier,
) -> Double {
  supplier.on_time_rate *
  @math.exp(-supplier.lead_time_variability / (1.0 + supplier.lead_time))
}

///|
pub fn reliability_supplier_continuity_score(
  supplier : ReliabilitySupplier,
) -> Double {
  let concentration_penalty = if supplier.single_source { 0.25 } else { 0.0 }
  (supplier.audit_score * (1.0 - concentration_penalty)).max(0.0)
}

///|
pub fn reliability_supplier_risk_score(
  supplier : ReliabilitySupplier,
) -> Double {
  let quality = reliability_supplier_quality_rate(supplier)
  let delivery = reliability_supplier_delivery_score(supplier)
  let continuity = reliability_supplier_continuity_score(supplier)
  (0.5 * quality + 0.3 * delivery + 0.2 * continuity).max(0.0).min(1.0)
}

///|
pub fn reliability_supplier_should_escalate(
  supplier : ReliabilitySupplier,
  minimum_score : Double,
) -> Bool {
  reliability_supplier_risk_score(supplier) < minimum_score ||
  supplier.tier is SupplierRestricted ||
  supplier.tier is SupplierDisqualified
}

///|
pub fn reliability_supplier_recommended_sample_fraction(
  supplier : ReliabilitySupplier,
) -> Double {
  match supplier.tier {
    SupplierApproved => 0.05
    SupplierMonitored => 0.2
    SupplierRestricted => 0.5
    SupplierDisqualified => 1.0
  }
}

///|
/// A received lot and its production risk exposure.
pub struct ReliabilitySupplierLot {
  lot_id : String
  supplier_id : String
  part_id : Int
  quantity : Int
  unit_cost : Double
  received_at : Double
  promised_at : Double
  criticality : Double
  traceability_complete : Bool
}

///|
pub fn reliability_supplier_lot(
  lot_id : String,
  supplier_id : String,
  part_id : Int,
  quantity : Int,
  unit_cost : Double,
  received_at : Double,
  promised_at : Double,
  criticality : Double,
  traceability_complete : Bool,
) -> ReliabilitySupplierLot {
  if part_id < 0 ||
    quantity < 0 ||
    unit_cost < 0.0 ||
    received_at < 0.0 ||
    promised_at < 0.0 ||
    criticality < 0.0 {
    abort("invalid supplier lot")
  }
  {
    lot_id,
    supplier_id,
    part_id,
    quantity,
    unit_cost,
    received_at,
    promised_at,
    criticality,
    traceability_complete,
  }
}

///|
pub fn reliability_supplier_lot_total_value(
  lot : ReliabilitySupplierLot,
) -> Double {
  lot.quantity.to_double() * lot.unit_cost
}

///|
pub fn reliability_supplier_lot_is_late(lot : ReliabilitySupplierLot) -> Bool {
  lot.received_at > lot.promised_at
}

///|
pub fn reliability_supplier_lot_delay(lot : ReliabilitySupplierLot) -> Double {
  (lot.received_at - lot.promised_at).max(0.0)
}

///|
pub fn reliability_supplier_lot_risk(
  lot : ReliabilitySupplierLot,
  supplier : ReliabilitySupplier,
) -> Double {
  let lateness = reliability_supplier_lot_delay(lot)
  let traceability = if lot.traceability_complete { 0.0 } else { 1.0 }
  let quality_risk = 1.0 - reliability_supplier_risk_score(supplier)
  (lot.criticality *
  (quality_risk + traceability + lateness / (1.0 + lot.promised_at))).max(0.0)
}

///|
/// Incoming inspection result for a lot.
pub struct ReliabilityIncomingInspection {
  inspection_id : Int
  lot_id : String
  sample_size : Int
  defect_count : Int
  critical_defects : Int
  inspected_value : Double
  accepted : Bool
  inspection_time : Double
}

///|
pub fn reliability_incoming_inspection(
  inspection_id : Int,
  lot_id : String,
  sample_size : Int,
  defect_count : Int,
  critical_defects : Int,
  inspected_value : Double,
  accepted : Bool,
  inspection_time : Double,
) -> ReliabilityIncomingInspection {
  if inspection_id < 0 ||
    sample_size < 0 ||
    defect_count < 0 ||
    critical_defects < 0 ||
    defect_count > sample_size ||
    critical_defects > defect_count ||
    inspected_value < 0.0 ||
    inspection_time < 0.0 {
    abort("invalid incoming inspection")
  }
  {
    inspection_id,
    lot_id,
    sample_size,
    defect_count,
    critical_defects,
    inspected_value,
    accepted,
    inspection_time,
  }
}

///|
pub fn reliability_incoming_defect_rate(
  inspection : ReliabilityIncomingInspection,
) -> Double {
  if inspection.sample_size == 0 {
    0.0
  } else {
    inspection.defect_count.to_double() / inspection.sample_size.to_double()
  }
}

///|
pub fn reliability_incoming_critical_rate(
  inspection : ReliabilityIncomingInspection,
) -> Double {
  if inspection.sample_size == 0 {
    0.0
  } else {
    inspection.critical_defects.to_double() / inspection.sample_size.to_double()
  }
}

///|
pub fn reliability_incoming_yield(
  inspection : ReliabilityIncomingInspection,
) -> Double {
  1.0 - reliability_incoming_defect_rate(inspection)
}

///|
pub fn reliability_incoming_cost_per_unit(
  inspection : ReliabilityIncomingInspection,
) -> Double {
  if inspection.sample_size == 0 {
    0.0
  } else {
    inspection.inspected_value / inspection.sample_size.to_double()
  }
}

///|
/// Attribute sampling plan derived from supplier risk and lot criticality.
pub struct ReliabilityIncomingPlan {
  sample_size : Int
  acceptance_number : Int
  rejection_number : Int
  inspection_fraction : Double
  rationale : String
}

///|
pub fn reliability_incoming_plan(
  lot_size : Int,
  supplier : ReliabilitySupplier,
  criticality : Double,
) -> ReliabilityIncomingPlan {
  if lot_size < 0 || criticality < 0.0 {
    abort("invalid incoming plan")
  }
  let fraction = (reliability_supplier_recommended_sample_fraction(supplier) *
  (0.5 + criticality.min(1.0))).min(1.0)
  let sample = (lot_size.to_double() * fraction)
    .ceil()
    .to_int()
    .min(lot_size)
    .max(0)
  let acceptance = if supplier.tier is SupplierApproved { 1 } else { 0 }
  let rationale = if supplier.single_source {
    "single-source continuity protection"
  } else {
    "risk-based incoming inspection"
  }
  {
    sample_size: sample,
    acceptance_number: acceptance,
    rejection_number: acceptance + 1,
    inspection_fraction: fraction,
    rationale,
  }
}

///|
pub fn reliability_incoming_plan_expected_cost(
  plan : ReliabilityIncomingPlan,
  inspection_cost_per_unit : Double,
  failure_cost : Double,
  defect_rate : Double,
  lot_size : Int,
) -> Double {
  if inspection_cost_per_unit < 0.0 ||
    failure_cost < 0.0 ||
    defect_rate < 0.0 ||
    lot_size < 0 {
    abort("invalid incoming plan cost")
  }
  plan.sample_size.to_double() * inspection_cost_per_unit +
  lot_size.to_double() *
  defect_rate *
  failure_cost *
  (1.0 - plan.inspection_fraction)
}

///|
pub fn reliability_incoming_plan_is_full_inspection(
  plan : ReliabilityIncomingPlan,
) -> Bool {
  plan.inspection_fraction >= 1.0
}

///|
/// Monthly quality scorecard used in supplier business reviews.
pub struct ReliabilitySupplierScorecard {
  supplier_id : String
  lots : Int
  inspected_units : Int
  defect_units : Int
  rejected_lots : Int
  total_value : Double
  on_time_deliveries : Int
  late_deliveries : Int
  audit_score : Double
}

///|
pub fn reliability_supplier_scorecard(
  supplier_id : String,
  lots : Int,
  inspected_units : Int,
  defect_units : Int,
  rejected_lots : Int,
  total_value : Double,
  on_time_deliveries : Int,
  late_deliveries : Int,
  audit_score : Double,
) -> ReliabilitySupplierScorecard {
  if lots < 0 ||
    inspected_units < 0 ||
    defect_units < 0 ||
    rejected_lots < 0 ||
    total_value < 0.0 ||
    on_time_deliveries < 0 ||
    late_deliveries < 0 ||
    audit_score < 0.0 ||
    audit_score > 1.0 {
    abort("invalid supplier scorecard")
  }
  {
    supplier_id,
    lots,
    inspected_units,
    defect_units,
    rejected_lots,
    total_value,
    on_time_deliveries,
    late_deliveries,
    audit_score,
  }
}

///|
pub fn reliability_scorecard_defect_rate(
  scorecard : ReliabilitySupplierScorecard,
) -> Double {
  if scorecard.inspected_units == 0 {
    0.0
  } else {
    scorecard.defect_units.to_double() / scorecard.inspected_units.to_double()
  }
}

///|
pub fn reliability_scorecard_rejection_rate(
  scorecard : ReliabilitySupplierScorecard,
) -> Double {
  if scorecard.lots == 0 {
    0.0
  } else {
    scorecard.rejected_lots.to_double() / scorecard.lots.to_double()
  }
}

///|
pub fn reliability_scorecard_delivery_rate(
  scorecard : ReliabilitySupplierScorecard,
) -> Double {
  let deliveries = scorecard.on_time_deliveries + scorecard.late_deliveries
  if deliveries == 0 {
    0.0
  } else {
    scorecard.on_time_deliveries.to_double() / deliveries.to_double()
  }
}

///|
pub fn reliability_scorecard_quality_score(
  scorecard : ReliabilitySupplierScorecard,
) -> Double {
  let defect = (1.0 - reliability_scorecard_defect_rate(scorecard)).max(0.0)
  let rejection = (1.0 - reliability_scorecard_rejection_rate(scorecard)).max(
    0.0,
  )
  let delivery = reliability_scorecard_delivery_rate(scorecard)
  (0.5 * defect + 0.2 * rejection + 0.2 * delivery + 0.1 * scorecard.audit_score).min(
    1.0,
  )
}

///|
pub fn reliability_scorecard_recommendation(
  scorecard : ReliabilitySupplierScorecard,
) -> SupplierRiskTier {
  let score = reliability_scorecard_quality_score(scorecard)
  if score >= 0.9 {
    SupplierRiskTier::SupplierApproved
  } else if score >= 0.7 {
    SupplierRiskTier::SupplierMonitored
  } else if score >= 0.4 {
    SupplierRiskTier::SupplierRestricted
  } else {
    SupplierRiskTier::SupplierDisqualified
  }
}

///|
pub fn reliability_supplier_portfolio_score(
  suppliers : Array[ReliabilitySupplier],
) -> Double {
  if suppliers.is_empty() {
    0.0
  } else {
    let spend = suppliers.fold(init=0.0, (sum, supplier) => {
      sum + supplier.annual_spend
    })
    if spend == 0.0 {
      suppliers.fold(init=0.0, (sum, supplier) => {
        sum + reliability_supplier_risk_score(supplier)
      }) /
      suppliers.length().to_double()
    } else {
      suppliers.fold(init=0.0, (sum, supplier) => {
        sum + reliability_supplier_risk_score(supplier) * supplier.annual_spend
      }) /
      spend
    }
  }
}

///|
pub fn reliability_supplier_restricted_ids(
  suppliers : Array[ReliabilitySupplier],
  threshold : Double,
) -> Array[String] {
  suppliers.filter_map(supplier => {
    if reliability_supplier_should_escalate(supplier, threshold) {
      Some(supplier.supplier_id)
    } else {
      None
    }
  })
}

///|
pub fn reliability_supplier_concentration(
  suppliers : Array[ReliabilitySupplier],
) -> Double {
  if suppliers.is_empty() {
    0.0
  } else {
    let total = suppliers.fold(init=0.0, (sum, supplier) => {
      sum + supplier.annual_spend
    })
    if total == 0.0 {
      0.0
    } else {
      let largest = suppliers.fold(init=0.0, (best, supplier) => {
        best.max(supplier.annual_spend)
      })
      largest / total
    }
  }
}

///|
pub fn reliability_supplier_diversification_score(
  suppliers : Array[ReliabilitySupplier],
) -> Double {
  1.0 - reliability_supplier_concentration(suppliers)
}

///|
pub fn reliability_supplier_portfolio_risk(
  suppliers : Array[ReliabilitySupplier],
) -> Double {
  let quality = reliability_supplier_portfolio_score(suppliers)
  let diversity = reliability_supplier_diversification_score(suppliers)
  (1.0 - (0.8 * quality + 0.2 * diversity)).max(0.0).min(1.0)
}

///|
pub fn reliability_supplier_resilience_actions(
  suppliers : Array[ReliabilitySupplier],
) -> Array[String] {
  let actions = Array::new()
  if reliability_supplier_concentration(suppliers) > 0.6 {
    actions.push("qualify a second source for the highest-spend part")
  }
  if reliability_supplier_portfolio_score(suppliers) < 0.7 {
    actions.push("open supplier corrective-action plans")
  }
  for supplier in suppliers {
    if supplier.lead_time_variability > supplier.lead_time {
      actions.push("review safety stock for a variable-lead-time supplier")
    }
  }
  actions
}

///|
pub fn reliability_supply_chain_checksum(
  suppliers : Array[ReliabilitySupplier],
  scorecards : Array[ReliabilitySupplierScorecard],
) -> Double {
  reliability_supplier_portfolio_score(suppliers) * 100.0 +
  reliability_supplier_portfolio_risk(suppliers) * 10.0 +
  scorecards.fold(init=0.0, (sum, scorecard) => {
    sum + reliability_scorecard_quality_score(scorecard)
  })
}
