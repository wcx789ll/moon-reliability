///|
test "maintenance resource planning boundaries" {
  let order = resource_work_order(
    1,
    42,
    0.0,
    8.0,
    2.0,
    ResourceMaintenancePriority::ResourceUrgent,
    ResourceWorkOrderState::ResourceQueued,
    "mechanical",
    [7, 8],
    2.0,
    1.0,
  )
  let crew = resource_crew(3, "A", "mechanical", 0.0, 8.0, 6.0, 1.0, 40.0, 1.0)
  let spare = resource_spare(7, 4, 0, 0, 2, 5, 10.0, 2.0, 1.0)
  let snapshot = resource_snapshot(4.0, [order], [crew], [spare])
  inspect(resource_work_order_is_open(order), content="true")
  inspect(resource_crew_can_accept(crew, order, 4.0), content="true")
  inspect(resource_spare_needs_reorder(spare), content="false")
  inspect(resource_snapshot_capacity_ratio(snapshot) > 0.0, content="true")
  inspect(resource_dispatch_success_rate([]), content="0")
}

///|
test "data quality and time series boundaries" {
  let sensor_row = reliability_data_row(1.0, 10, 4.0, 0, true, false, 1.0)
  let censored_row = reliability_data_row(2.0, 10, 5.0, 0, false, true, 0.8)
  let column = reliability_data_column(
    "temperature",
    ReliabilityDataKind::ReliabilityContinuous,
    2,
    0,
    0,
    0,
    4.0,
    5.0,
    4.5,
    0.7,
    0,
  )
  let dataset = reliability_data_set(
    "demo",
    "1",
    [sensor_row, censored_row],
    [column],
    1.0,
    2.0,
    1,
  )
  let rule = reliability_data_rule("quality", "source quality", 0.7, 1.0, true)
  let result = reliability_data_rule_result(
    rule,
    reliability_data_set_quality(dataset),
  )
  let report = reliability_data_quality_report(dataset, [result], 0.5)
  inspect(reliability_data_set_failure_count(dataset), content="1")
  inspect(reliability_data_column_is_usable(column, 0.5), content="true")
  inspect(reliability_data_report_has_blocker(report), content="false")
  inspect(reliability_data_first_difference([4.0]).length(), content="0")
  inspect(reliability_data_moving_average([1.0, 3.0], 1)[1], content="3")
}

///|
test "experimental design and power boundaries" {
  let low = reliability_factor("load", 0.0, 0.0, 1.0)
  let high = reliability_factor("load", 1.0, 0.0, 1.0)
  let trials = [
    reliability_trial(1, [low], 10.0, 100.0, 1, false, 1),
    reliability_trial(2, [low], 11.0, 100.0, 1, false, 2),
    reliability_trial(3, [high], 15.0, 100.0, 2, false, 1),
    reliability_trial(4, [high], 14.0, 100.0, 2, false, 2),
  ]
  let low_cell = reliability_treatment_cell(1, [low], [trials[0], trials[1]])
  let high_cell = reliability_treatment_cell(2, [high], [trials[2], trials[3]])
  let effect = reliability_main_effect(trials, "load")
  let anova = reliability_anova([low_cell, high_cell])
  let power = reliability_power_plan(2.0, 1.0, 0.05, 0.8)
  inspect(reliability_cell_trial_count(low_cell), content="2")
  inspect(effect.effect > 0.0, content="true")
  inspect(anova.between_sum_squares > 0.0, content="true")
  inspect(reliability_power_plan_total_sample(power) >= 2, content="true")
}

///|
test "warranty and extreme age boundaries" {
  let warranty = reliability_warranty(
    "w1", "pump", 0.0, 100.0, 5.0, 50.0, 0.1, false,
  )
  let claim = reliability_warranty_claim(
    1, 8, "w1", 20.0, 1.0, 3.0, 10.0, 1.5, false, true, 2.0,
  )
  let cohort = reliability_warranty_cohort(
    1,
    "pump",
    10,
    100.0,
    [claim],
    100.0,
    0.2,
  )
  let curve = reliability_warranty_hazard_curve([0.0, 50.0, 100.0], [
    0.01, 0.02, 0.03,
  ])
  inspect(reliability_warranty_is_active(warranty, 0.0), content="true")
  inspect(reliability_warranty_claim_cycle_time(claim), content="2")
  inspect(reliability_warranty_cohort_claim_count(cohort), content="1")
  inspect(reliability_warranty_survival_probability(curve, 0.0), content="1")
  inspect(
    reliability_warranty_claim_probability(curve, 100.0) > 0.0,
    content="true",
  )
}

///|
test "supplier quality and sampling boundaries" {
  let supplier = reliability_supplier(
    "s1",
    "Supplier One",
    SupplierRiskTier::SupplierMonitored,
    120.0,
    0.95,
    0.9,
    5.0,
    1.0,
    1000.0,
    false,
  )
  let lot = reliability_supplier_lot(
    "l1", "s1", 3, 100, 2.0, 10.0, 8.0, 1.0, true,
  )
  let inspection = reliability_incoming_inspection(
    1, "l1", 10, 1, 0, 20.0, true, 1.0,
  )
  let plan = reliability_incoming_plan(100, supplier, 1.0)
  let scorecard = reliability_supplier_scorecard(
    "s1", 4, 40, 2, 0, 100.0, 3, 1, 0.9,
  )
  inspect(reliability_supplier_lot_is_late(lot), content="true")
  inspect(reliability_incoming_defect_rate(inspection) > 0.09, content="true")
  inspect(plan.sample_size > 0, content="true")
  inspect(reliability_scorecard_quality_score(scorecard) > 0.0, content="true")
}

///|
test "condition monitoring boundaries" {
  let sensor = reliability_sensor(
    "v1",
    9,
    ReliabilitySignalKind::ReliabilityVibration,
    "mm/s",
    0.0,
    10.0,
    1.0,
    0.0,
    1.0,
    true,
  )
  let reading_a = reliability_reading(sensor, 0.0, 2.0, 1.0, 0)
  let reading_b = reliability_reading(sensor, 1.0, 4.0, 1.0, 1)
  let feature = reliability_health_feature("trend", 4.0, 2.0, 4.0, 1.0, 1.0)
  let policy = reliability_health_policy(0.2, 0.5, 0.8, 0.5, 2)
  let assessment = reliability_condition_assessment(
    9,
    1.0,
    [feature],
    1.0,
    policy,
  )
  let rul = reliability_rul_from_linear_health(9, 10.0, 0.8, -0.01, 0.2, 1.0)
  inspect(
    reliability_sensor_is_in_limit(sensor, reading_a.value),
    content="true",
  )
  inspect(reliability_reading_rate(reading_a, reading_b), content="2")
  inspect(reliability_assessment_top_feature(assessment), content="trend")
  inspect(reliability_rul_is_due(rul, 100.0), content="true")
  inspect(reliability_condition_batch_risk([]), content="0")
}

///|
test "risk register and governance boundaries" {
  let risk = reliability_risk_record(
    "r1",
    "pump seizure",
    "owner",
    "mechanical",
    0.2,
    50.0,
    0.3,
    1.0,
    ReliabilityRiskStatus::ReliabilityRiskOpen,
    ReliabilityRiskTreatment::ReliabilityRiskReduce,
    10.0,
    2.0,
    0.0,
  )
  let control = reliability_risk_control(
    "c1", "r1", "inspection", "detective", "owner", 0.8, 0.9, 2.0, 0.0, 2, true,
  )
  let action = reliability_risk_action(
    "a1", "r1", "owner", "increase inspection", 10.0, 4.0, 0.5, 8.0, true, true,
  )
  let review = reliability_risk_review(5.0, [risk], [control], [action])
  let model = reliability_model_record(
    "m1",
    "demo",
    "1",
    "owner",
    "weibull",
    ReliabilityModelStage::ReliabilityModelValidated,
    100,
    2,
    0.0,
    10.0,
    1.0,
    2.0,
  )
  let metric = reliability_model_metric("rmse", 0.1, 0.2, 0.05, false, 1.0)
  let validation = reliability_validation_run(
    "v1",
    "m1",
    1.0,
    2.0,
    "demo",
    [metric],
    "reviewer",
    true,
  )
  let evidence = reliability_evidence(
    "e1", "m1", "benchmark", "local", 2.0, 1.0, 4.0, true,
  )
  let change = reliability_change_request(
    "ch1", "m1", "owner", "refresh", 1.0, 1.0, 2.0, 5.0, true, true, true,
  )
  let governance = reliability_governance_snapshot(
    3.0,
    [model],
    [validation],
    [evidence],
    [change],
  )
  inspect(reliability_risk_score(risk) > 0.0, content="true")
  inspect(reliability_control_is_evidence_backed(control), content="true")
  inspect(reliability_risk_review_open_fraction(review), content="1")
  inspect(reliability_validation_is_release_ready(validation), content="true")
  inspect(reliability_change_is_releasable(change), content="true")
  inspect(governance.readiness > 0.0, content="true")
}

///|
test "field service operations boundaries" {
  let case = reliability_service_case(
    "case-1",
    4,
    0.0,
    8.0,
    ReliabilityServiceCaseState::ReliabilityCaseNew,
    ReliabilityServiceUrgency::ReliabilityServiceHigh,
    "overheat",
    2.0,
    1.0,
    false,
    true,
  )
  let technician = reliability_technician(
    "t1", "Tech", "thermal", 0.0, 0.0, 0.0, 8.0, 8.0, 40.0, true,
  )
  let visit = reliability_service_visit(
    "v1", "case-1", "t1", 1.0, 2.0, 4.0, 0.5, 1.5, 10.0, true, 1.0,
  )
  let part = reliability_service_part_use("case-1", 7, 2, 5.0, 1, false)
  let sla = reliability_service_sla("s1", 2.0, 5.0, 0.9, 10.0, 2.0)
  let outcome = reliability_service_outcome(
    "case-1", "seal", "replace", true, true, false, 2.0, 30.0, 1.0,
  )
  let summary = reliability_service_summary(
    5.0,
    [case],
    [visit],
    [outcome],
    sla,
  )
  inspect(reliability_service_case_is_open(case), content="true")
  inspect(reliability_service_visit_response_time(visit), content="1")
  inspect(reliability_service_part_net_quantity(part), content="1")
  inspect(reliability_service_sla_is_met(sla, [visit]), content="true")
  inspect(reliability_service_summary_cost_per_case(summary), content="30")
  inspect(reliability_service_dispatch_capacity([technician]), content="8")
}
