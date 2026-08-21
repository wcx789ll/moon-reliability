///|
/// Status of an operational reliability risk in the risk register.
pub(all) enum ReliabilityRiskStatus {
  ReliabilityRiskOpen
  ReliabilityRiskMitigating
  ReliabilityRiskAccepted
  ReliabilityRiskClosed
} derive(Debug, Eq)

///|
/// Treatment strategy selected by the accountable engineering owner.
pub(all) enum ReliabilityRiskTreatment {
  ReliabilityRiskAvoid
  ReliabilityRiskReduce
  ReliabilityRiskTransfer
  ReliabilityRiskAccept
} derive(Debug, Eq)

///|
/// A risk register entry connecting a failure scenario to business impact.
pub struct ReliabilityRiskRecord {
  risk_id : String
  title : String
  owner : String
  category : String
  probability : Double
  consequence : Double
  detectability : Double
  exposure : Double
  status : ReliabilityRiskStatus
  treatment : ReliabilityRiskTreatment
  due_at : Double
  review_interval : Double
  last_reviewed : Double
}

///|
pub fn reliability_risk_record(
  risk_id : String,
  title : String,
  owner : String,
  category : String,
  probability : Double,
  consequence : Double,
  detectability : Double,
  exposure : Double,
  status : ReliabilityRiskStatus,
  treatment : ReliabilityRiskTreatment,
  due_at : Double,
  review_interval : Double,
  last_reviewed : Double,
) -> ReliabilityRiskRecord {
  if probability < 0.0 ||
    probability > 1.0 ||
    consequence < 0.0 ||
    detectability < 0.0 ||
    detectability > 1.0 ||
    exposure < 0.0 ||
    due_at < 0.0 ||
    review_interval < 0.0 ||
    last_reviewed < 0.0 {
    abort("invalid reliability risk record")
  }
  {
    risk_id,
    title,
    owner,
    category,
    probability,
    consequence,
    detectability,
    exposure,
    status,
    treatment,
    due_at,
    review_interval,
    last_reviewed,
  }
}

///|
pub fn reliability_risk_score(risk : ReliabilityRiskRecord) -> Double {
  risk.probability *
  risk.consequence *
  (1.0 + risk.exposure) *
  (1.0 - risk.detectability)
}

///|
pub fn reliability_risk_residual_score(
  risk : ReliabilityRiskRecord,
  control_effectiveness : Double,
) -> Double {
  if control_effectiveness < 0.0 || control_effectiveness > 1.0 {
    abort("control effectiveness must be in [0, 1]")
  }
  reliability_risk_score(risk) * (1.0 - control_effectiveness)
}

///|
pub fn reliability_risk_is_open(risk : ReliabilityRiskRecord) -> Bool {
  risk.status is ReliabilityRiskOpen || risk.status is ReliabilityRiskMitigating
}

///|
pub fn reliability_risk_is_overdue(
  risk : ReliabilityRiskRecord,
  as_of : Double,
) -> Bool {
  reliability_risk_is_open(risk) && as_of > risk.due_at
}

///|
pub fn reliability_risk_next_review(risk : ReliabilityRiskRecord) -> Double {
  risk.last_reviewed + risk.review_interval
}

///|
pub fn reliability_risk_review_due(
  risk : ReliabilityRiskRecord,
  as_of : Double,
) -> Bool {
  risk.review_interval > 0.0 && as_of >= reliability_risk_next_review(risk)
}

///|
pub fn reliability_risk_priority(risk : ReliabilityRiskRecord) -> Int {
  let score = reliability_risk_score(risk)
  if score >= 100.0 {
    4
  } else if score >= 50.0 {
    3
  } else if score >= 10.0 {
    2
  } else if score > 0.0 {
    1
  } else {
    0
  }
}

///|
pub fn reliability_risk_status_label(status : ReliabilityRiskStatus) -> String {
  match status {
    ReliabilityRiskOpen => "open"
    ReliabilityRiskMitigating => "mitigating"
    ReliabilityRiskAccepted => "accepted"
    ReliabilityRiskClosed => "closed"
  }
}

///|
pub fn reliability_risk_treatment_label(
  treatment : ReliabilityRiskTreatment,
) -> String {
  match treatment {
    ReliabilityRiskAvoid => "avoid"
    ReliabilityRiskReduce => "reduce"
    ReliabilityRiskTransfer => "transfer"
    ReliabilityRiskAccept => "accept"
  }
}

///|
/// A preventive, detective, or recovery control mapped to a risk.
pub struct ReliabilityRiskControl {
  control_id : String
  risk_id : String
  title : String
  control_type : String
  owner : String
  design_effectiveness : Double
  operating_effectiveness : Double
  test_frequency : Double
  last_tested : Double
  evidence_count : Int
  automated : Bool
}

///|
pub fn reliability_risk_control(
  control_id : String,
  risk_id : String,
  title : String,
  control_type : String,
  owner : String,
  design_effectiveness : Double,
  operating_effectiveness : Double,
  test_frequency : Double,
  last_tested : Double,
  evidence_count : Int,
  automated : Bool,
) -> ReliabilityRiskControl {
  if design_effectiveness < 0.0 ||
    design_effectiveness > 1.0 ||
    operating_effectiveness < 0.0 ||
    operating_effectiveness > 1.0 ||
    test_frequency < 0.0 ||
    last_tested < 0.0 ||
    evidence_count < 0 {
    abort("invalid reliability risk control")
  }
  {
    control_id,
    risk_id,
    title,
    control_type,
    owner,
    design_effectiveness,
    operating_effectiveness,
    test_frequency,
    last_tested,
    evidence_count,
    automated,
  }
}

///|
pub fn reliability_control_effectiveness(
  control : ReliabilityRiskControl,
) -> Double {
  control.design_effectiveness * control.operating_effectiveness
}

///|
pub fn reliability_control_is_evidence_backed(
  control : ReliabilityRiskControl,
) -> Bool {
  control.evidence_count > 0 && control.operating_effectiveness > 0.0
}

///|
pub fn reliability_control_test_due(
  control : ReliabilityRiskControl,
  as_of : Double,
) -> Bool {
  control.test_frequency > 0.0 &&
  as_of >= control.last_tested + control.test_frequency
}

///|
pub fn reliability_control_coverage(
  controls : Array[ReliabilityRiskControl],
  risk_id : String,
) -> Double {
  let selected = controls.filter(control => control.risk_id == risk_id)
  if selected.is_empty() {
    0.0
  } else {
    selected.fold(init=0.0, (sum, control) => {
      sum + reliability_control_effectiveness(control)
    }) /
    selected.length().to_double()
  }
}

///|
pub fn reliability_control_weak_ids(
  controls : Array[ReliabilityRiskControl],
  threshold : Double,
) -> Array[String] {
  controls.filter_map(control => {
    if reliability_control_effectiveness(control) < threshold {
      Some(control.control_id)
    } else {
      None
    }
  })
}

///|
pub fn reliability_control_untested_ids(
  controls : Array[ReliabilityRiskControl],
  as_of : Double,
) -> Array[String] {
  controls.filter_map(control => {
    if reliability_control_test_due(control, as_of) {
      Some(control.control_id)
    } else {
      None
    }
  })
}

///|
/// Remediation action with a measurable expected risk reduction.
pub struct ReliabilityRiskAction {
  action_id : String
  risk_id : String
  owner : String
  description : String
  cost : Double
  effort_hours : Double
  expected_reduction : Double
  due_at : Double
  completed : Bool
  verified : Bool
}

///|
pub fn reliability_risk_action(
  action_id : String,
  risk_id : String,
  owner : String,
  description : String,
  cost : Double,
  effort_hours : Double,
  expected_reduction : Double,
  due_at : Double,
  completed : Bool,
  verified : Bool,
) -> ReliabilityRiskAction {
  if cost < 0.0 ||
    effort_hours < 0.0 ||
    expected_reduction < 0.0 ||
    expected_reduction > 1.0 ||
    due_at < 0.0 ||
    (verified && !completed) {
    abort("invalid reliability risk action")
  }
  {
    action_id,
    risk_id,
    owner,
    description,
    cost,
    effort_hours,
    expected_reduction,
    due_at,
    completed,
    verified,
  }
}

///|
pub fn reliability_risk_action_is_late(
  action : ReliabilityRiskAction,
  as_of : Double,
) -> Bool {
  !action.completed && as_of > action.due_at
}

///|
pub fn reliability_risk_action_realized_reduction(
  action : ReliabilityRiskAction,
) -> Double {
  if action.completed && action.verified {
    action.expected_reduction
  } else {
    0.0
  }
}

///|
pub fn reliability_risk_action_value(action : ReliabilityRiskAction) -> Double {
  if action.cost == 0.0 {
    action.expected_reduction
  } else {
    action.expected_reduction / action.cost
  }
}

///|
pub fn reliability_risk_action_plan_score(
  actions : Array[ReliabilityRiskAction],
) -> Double {
  let cost = actions.fold(init=0.0, (sum, action) => sum + action.cost)
  let reduction = actions.fold(init=0.0, (sum, action) => {
    sum + reliability_risk_action_realized_reduction(action)
  })
  if cost == 0.0 {
    reduction
  } else {
    reduction / cost
  }
}

///|
/// A risk register review snapshot for governance reporting.
pub struct ReliabilityRiskReview {
  as_of : Double
  total_risks : Int
  open_risks : Int
  overdue_risks : Int
  due_reviews : Int
  total_exposure : Double
  weighted_score : Double
  residual_score : Double
  control_coverage : Double
  action_completion : Double
}

///|
pub fn reliability_risk_review(
  as_of : Double,
  risks : Array[ReliabilityRiskRecord],
  controls : Array[ReliabilityRiskControl],
  actions : Array[ReliabilityRiskAction],
) -> ReliabilityRiskReview {
  let open = risks.filter(risk => reliability_risk_is_open(risk))
  let overdue = risks.filter(risk => reliability_risk_is_overdue(risk, as_of))
  let due = risks.filter(risk => reliability_risk_review_due(risk, as_of))
  let exposure = risks.fold(init=0.0, (sum, risk) => sum + risk.exposure)
  let weighted = risks.fold(init=0.0, (sum, risk) => {
    sum + reliability_risk_score(risk)
  })
  let residual = risks.fold(init=0.0, (sum, risk) => {
    sum +
    reliability_risk_score(risk) *
    (1.0 - reliability_control_coverage(controls, risk.risk_id))
  })
  let coverage = if risks.is_empty() {
    1.0
  } else {
    risks.fold(init=0.0, (sum, risk) => {
      sum + reliability_control_coverage(controls, risk.risk_id)
    }) /
    risks.length().to_double()
  }
  let completion = if actions.is_empty() {
    1.0
  } else {
    actions
    .fold(init=0, (count, action) => {
      if action.completed {
        count + 1
      } else {
        count
      }
    })
    .to_double() /
    actions.length().to_double()
  }
  {
    as_of,
    total_risks: risks.length(),
    open_risks: open.length(),
    overdue_risks: overdue.length(),
    due_reviews: due.length(),
    total_exposure: exposure,
    weighted_score: weighted,
    residual_score: residual,
    control_coverage: coverage,
    action_completion: completion,
  }
}

///|
pub fn reliability_risk_review_readiness(
  review : ReliabilityRiskReview,
) -> Double {
  let exposure_score = 1.0 / (1.0 + review.residual_score)
  (0.35 * review.control_coverage +
  0.35 * review.action_completion +
  0.3 * exposure_score)
  .min(1.0)
  .max(0.0)
}

///|
pub fn reliability_risk_review_has_blocker(
  review : ReliabilityRiskReview,
) -> Bool {
  review.overdue_risks > 0 ||
  review.control_coverage < 0.5 ||
  review.action_completion < 0.5
}

///|
pub fn reliability_risk_review_open_fraction(
  review : ReliabilityRiskReview,
) -> Double {
  if review.total_risks == 0 {
    0.0
  } else {
    review.open_risks.to_double() / review.total_risks.to_double()
  }
}

///|
pub fn reliability_risk_overdue_ids(
  risks : Array[ReliabilityRiskRecord],
  as_of : Double,
) -> Array[String] {
  risks.filter_map(risk => {
    if reliability_risk_is_overdue(risk, as_of) {
      Some(risk.risk_id)
    } else {
      None
    }
  })
}

///|
pub fn reliability_risk_due_review_ids(
  risks : Array[ReliabilityRiskRecord],
  as_of : Double,
) -> Array[String] {
  risks.filter_map(risk => {
    if reliability_risk_review_due(risk, as_of) {
      Some(risk.risk_id)
    } else {
      None
    }
  })
}

///|
pub fn reliability_risk_ranked(
  risks : Array[ReliabilityRiskRecord],
) -> Array[ReliabilityRiskRecord] {
  let result = risks.copy()
  result.sort_by((left, right) => {
    let a = reliability_risk_score(left)
    let b = reliability_risk_score(right)
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
pub fn reliability_risk_category_score(
  risks : Array[ReliabilityRiskRecord],
  category : String,
) -> Double {
  risks.fold(init=0.0, (sum, risk) => {
    if risk.category == category {
      sum + reliability_risk_score(risk)
    } else {
      sum
    }
  })
}

///|
pub fn reliability_risk_owner_load(
  risks : Array[ReliabilityRiskRecord],
  owner : String,
) -> Int {
  risks.fold(init=0, (count, risk) => {
    if risk.owner == owner && reliability_risk_is_open(risk) {
      count + 1
    } else {
      count
    }
  })
}

///|
pub fn reliability_risk_action_owner_load(
  actions : Array[ReliabilityRiskAction],
  owner : String,
) -> Double {
  actions.fold(init=0.0, (sum, action) => {
    if action.owner == owner && !action.completed {
      sum + action.effort_hours
    } else {
      sum
    }
  })
}

///|
pub fn reliability_risk_select_actions(
  actions : Array[ReliabilityRiskAction],
  budget : Double,
) -> Array[String] {
  if budget < 0.0 {
    abort("risk action budget must be non-negative")
  }
  let ordered = actions.copy()
  ordered.sort_by((left, right) => {
    let a = reliability_risk_action_value(left)
    let b = reliability_risk_action_value(right)
    if a > b {
      -1
    } else if a < b {
      1
    } else {
      0
    }
  })
  let result = Array::new()
  let mut remaining = budget
  for action in ordered {
    if !action.completed && action.cost <= remaining {
      result.push(action.action_id)
      remaining -= action.cost
    }
  }
  result
}

///|
pub fn reliability_risk_portfolio_loss(
  risks : Array[ReliabilityRiskRecord],
  controls : Array[ReliabilityRiskControl],
) -> Double {
  risks.fold(init=0.0, (sum, risk) => {
    sum +
    reliability_risk_score(risk) *
    (1.0 - reliability_control_coverage(controls, risk.risk_id))
  })
}

///|
pub fn reliability_risk_portfolio_benefit(
  risks : Array[ReliabilityRiskRecord],
  actions : Array[ReliabilityRiskAction],
) -> Double {
  risks.fold(init=0.0, (sum, risk) => {
    let reduction = actions.fold(init=0.0, (value, action) => {
      if action.risk_id == risk.risk_id {
        value + reliability_risk_action_realized_reduction(action)
      } else {
        value
      }
    })
    sum + reliability_risk_score(risk) * reduction.min(1.0)
  })
}

///|
pub fn reliability_risk_register_checksum(
  review : ReliabilityRiskReview,
  risks : Array[ReliabilityRiskRecord],
) -> Double {
  review.weighted_score +
  review.residual_score +
  review.control_coverage * 100.0 +
  risks.fold(init=0.0, (sum, risk) => sum + risk.probability + risk.consequence)
}
