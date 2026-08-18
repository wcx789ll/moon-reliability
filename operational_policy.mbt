///|
/// Operational policy for selecting an action from a reliability signal.
pub(all) enum PolicyAction {
  ContinueMonitoring
  InspectSoon
  ScheduleMaintenance
  RemoveFromService
} derive(Debug, Eq)

///|
pub struct PolicyDecision {
  action : PolicyAction
  score : Double
  reason : String
  urgency_hours : Double
}

///|
pub fn policy_decision(
  action~ : PolicyAction,
  score~ : Double,
  reason~ : String,
  urgency_hours~ : Double,
) -> PolicyDecision {
  { action, score, reason, urgency_hours }
}

///|
pub fn decide_policy(
  survival : Double,
  hazard : Double,
  target_survival : Double,
  hazard_limit : Double,
  hours_since_service : Double,
) -> PolicyDecision {
  if survival < target_survival * 0.5 {
    policy_decision(
      action=RemoveFromService,
      score=0.0,
      reason="mission survival is materially below the operating target",
      urgency_hours=0.0,
    )
  } else if hazard > hazard_limit {
    policy_decision(
      action=ScheduleMaintenance,
      score=hazard / hazard_limit,
      reason="estimated hazard exceeds the maintenance threshold",
      urgency_hours=24.0,
    )
  } else if hours_since_service > 1000.0 {
    policy_decision(
      action=InspectSoon,
      score=hours_since_service / 1000.0,
      reason="service interval has elapsed",
      urgency_hours=168.0,
    )
  } else {
    policy_decision(
      action=ContinueMonitoring,
      score=survival,
      reason="current indicators remain within operating policy",
      urgency_hours=720.0,
    )
  }
}

///|
pub fn policy_action_label(action : PolicyAction) -> String {
  match action {
    ContinueMonitoring => "monitor"
    InspectSoon => "inspect"
    ScheduleMaintenance => "maintain"
    RemoveFromService => "remove"
  }
}

///|
pub fn policy_risk_score(
  model : ReliabilityModel,
  time : Double,
  target : Double,
  hazard_limit : Double,
) -> Double {
  let survival_gap = (target - model.survival(time)).max(0.0)
  let hazard_gap = (model_hazard(model, time) - hazard_limit).max(0.0)
  survival_gap + hazard_gap
}

///|
pub fn policy_score_curve(
  model : ReliabilityModel,
  times : Array[Double],
  target : Double,
  hazard_limit : Double,
) -> Array[Double] {
  times.map(time => policy_risk_score(model, time, target, hazard_limit))
}

///|
pub fn policy_breach_count(scores : Array[Double], threshold : Double) -> Int {
  scores.fold(init=0, (count, score) => {
    if score > threshold {
      count + 1
    } else {
      count
    }
  })
}

///|
pub fn monitoring_interval(score : Double, base_hours : Double) -> Double {
  if score <= 0.0 {
    base_hours
  } else {
    base_hours / (1.0 + score).min(10.0)
  }
}

///|
pub fn alert_budget(score : Double, daily_budget : Int) -> Int {
  if daily_budget < 0 {
    abort("daily budget cannot be negative")
  }
  (daily_budget.to_double() * (1.0 - score.min(1.0))).floor().to_int()
}

///|
pub fn action_from_metric(
  metric : MetricEstimate,
  target : Double,
) -> PolicyAction {
  if metric.lower < target * 0.5 {
    RemoveFromService
  } else if metric.lower < target {
    ScheduleMaintenance
  } else {
    ContinueMonitoring
  }
}

///|
pub fn policy_report(decisions : Array[PolicyDecision]) -> String {
  let builder = StringBuilder::new()
  builder.write_string("action,score,urgency_hours,reason\n")
  for decision in decisions {
    builder.write_string(
      "\{policy_action_label(decision.action)},\{decision.score},\{decision.urgency_hours},\{decision.reason}\n",
    )
  }
  builder.to_string()
}

///|
pub fn policy_decisions_for_curve(
  model : ReliabilityModel,
  times : Array[Double],
  target : Double,
  hazard_limit : Double,
) -> Array[PolicyDecision] {
  times.map(time => {
    decide_policy(
      model.survival(time),
      model_hazard(model, time),
      target,
      hazard_limit,
      0.0,
    )
  })
}

///|
pub fn policy_compliance(decisions : Array[PolicyDecision]) -> Double {
  if decisions.is_empty() {
    1.0
  } else {
    decisions
    .filter(decision => decision.action is ContinueMonitoring)
    .length()
    .to_double() /
    decisions.length().to_double()
  }
}
