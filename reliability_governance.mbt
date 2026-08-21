///|
/// Promotion stage for a reliability model used in production decisions.
pub(all) enum ReliabilityModelStage {
  ReliabilityModelDraft
  ReliabilityModelValidated
  ReliabilityModelApproved
  ReliabilityModelRetired
} derive(Debug, Eq)

///|
/// Outcome of a repeatable model validation run.
pub(all) enum ReliabilityValidationStatus {
  ReliabilityValidationPassed
  ReliabilityValidationWarning
  ReliabilityValidationFailed
} derive(Debug, Eq)

///|
/// Registry metadata for an analyzable reliability model.
pub struct ReliabilityModelRecord {
  model_id : String
  name : String
  version : String
  owner : String
  family : String
  stage : ReliabilityModelStage
  training_rows : Int
  training_failures : Int
  created_at : Double
  expires_at : Double
  data_checksum : Double
  code_checksum : Double
}

///|
pub fn reliability_model_record(
  model_id : String,
  name : String,
  version : String,
  owner : String,
  family : String,
  stage : ReliabilityModelStage,
  training_rows : Int,
  training_failures : Int,
  created_at : Double,
  expires_at : Double,
  data_checksum : Double,
  code_checksum : Double,
) -> ReliabilityModelRecord {
  if training_rows < 0 ||
    training_failures < 0 ||
    training_failures > training_rows ||
    created_at < 0.0 ||
    expires_at < created_at {
    abort("invalid reliability model record")
  }
  {
    model_id,
    name,
    version,
    owner,
    family,
    stage,
    training_rows,
    training_failures,
    created_at,
    expires_at,
    data_checksum,
    code_checksum,
  }
}

///|
pub fn reliability_model_failure_fraction(
  model : ReliabilityModelRecord,
) -> Double {
  if model.training_rows == 0 {
    0.0
  } else {
    model.training_failures.to_double() / model.training_rows.to_double()
  }
}

///|
pub fn reliability_model_is_expired(
  model : ReliabilityModelRecord,
  as_of : Double,
) -> Bool {
  model.expires_at > model.created_at && as_of > model.expires_at
}

///|
pub fn reliability_model_is_deployable(
  model : ReliabilityModelRecord,
  as_of : Double,
) -> Bool {
  model.stage is ReliabilityModelApproved &&
  !reliability_model_is_expired(model, as_of)
}

///|
pub fn reliability_model_stage_label(stage : ReliabilityModelStage) -> String {
  match stage {
    ReliabilityModelDraft => "draft"
    ReliabilityModelValidated => "validated"
    ReliabilityModelApproved => "approved"
    ReliabilityModelRetired => "retired"
  }
}

///|
pub fn reliability_model_checksum(model : ReliabilityModelRecord) -> Double {
  model.data_checksum +
  model.code_checksum +
  model.training_rows.to_double() +
  model.training_failures.to_double()
}

///|
/// A metric with direction, target, and observed validation value.
pub struct ReliabilityModelMetric {
  metric_id : String
  observed : Double
  target : Double
  tolerance : Double
  higher_is_better : Bool
  weight : Double
}

///|
pub fn reliability_model_metric(
  metric_id : String,
  observed : Double,
  target : Double,
  tolerance : Double,
  higher_is_better : Bool,
  weight : Double,
) -> ReliabilityModelMetric {
  if tolerance < 0.0 || weight < 0.0 {
    abort("invalid model metric")
  }
  { metric_id, observed, target, tolerance, higher_is_better, weight }
}

///|
pub fn reliability_model_metric_gap(metric : ReliabilityModelMetric) -> Double {
  if metric.higher_is_better {
    metric.observed - metric.target
  } else {
    metric.target - metric.observed
  }
}

///|
pub fn reliability_model_metric_passes(metric : ReliabilityModelMetric) -> Bool {
  reliability_model_metric_gap(metric) >= -metric.tolerance
}

///|
pub fn reliability_model_metric_score(
  metric : ReliabilityModelMetric,
) -> Double {
  let gap = reliability_model_metric_gap(metric)
  if metric.target == 0.0 {
    if reliability_model_metric_passes(metric) {
      1.0
    } else {
      0.0
    }
  } else {
    (1.0 + gap / metric.target.abs()).max(0.0).min(1.0)
  }
}

///|
pub fn reliability_model_metric_weighted_score(
  metric : ReliabilityModelMetric,
) -> Double {
  reliability_model_metric_score(metric) * metric.weight
}

///|
pub fn reliability_model_metric_status(
  metric : ReliabilityModelMetric,
) -> ReliabilityValidationStatus {
  if reliability_model_metric_passes(metric) {
    ReliabilityValidationPassed
  } else if reliability_model_metric_gap(metric) >= -2.0 * metric.tolerance {
    ReliabilityValidationWarning
  } else {
    ReliabilityValidationFailed
  }
}

///|
/// A validation run includes data, calibration, and performance evidence.
pub struct ReliabilityValidationRun {
  run_id : String
  model_id : String
  started_at : Double
  finished_at : Double
  dataset_id : String
  metrics : Array[ReliabilityModelMetric]
  status : ReliabilityValidationStatus
  reviewer : String
  reproducible : Bool
}

///|
pub fn reliability_validation_run(
  run_id : String,
  model_id : String,
  started_at : Double,
  finished_at : Double,
  dataset_id : String,
  metrics : Array[ReliabilityModelMetric],
  reviewer : String,
  reproducible : Bool,
) -> ReliabilityValidationRun {
  if started_at < 0.0 || finished_at < started_at {
    abort("invalid validation run")
  }
  let status = metrics.fold(init=ReliabilityValidationPassed, (current, metric) => {
    let next = reliability_model_metric_status(metric)
    if next is ReliabilityValidationFailed {
      ReliabilityValidationFailed
    } else if next is ReliabilityValidationWarning &&
      current is ReliabilityValidationPassed {
      ReliabilityValidationWarning
    } else {
      current
    }
  })
  {
    run_id,
    model_id,
    started_at,
    finished_at,
    dataset_id,
    metrics,
    status,
    reviewer,
    reproducible,
  }
}

///|
pub fn reliability_validation_duration(
  run : ReliabilityValidationRun,
) -> Double {
  run.finished_at - run.started_at
}

///|
pub fn reliability_validation_score(run : ReliabilityValidationRun) -> Double {
  let weight = run.metrics.fold(init=0.0, (sum, metric) => sum + metric.weight)
  if weight == 0.0 {
    1.0
  } else {
    run.metrics.fold(init=0.0, (sum, metric) => {
      sum + reliability_model_metric_weighted_score(metric)
    }) /
    weight
  }
}

///|
pub fn reliability_validation_failed_metrics(
  run : ReliabilityValidationRun,
) -> Array[String] {
  run.metrics.filter_map(metric => {
    if reliability_model_metric_passes(metric) {
      None
    } else {
      Some(metric.metric_id)
    }
  })
}

///|
pub fn reliability_validation_is_release_ready(
  run : ReliabilityValidationRun,
) -> Bool {
  run.status is ReliabilityValidationPassed &&
  run.reproducible &&
  reliability_validation_score(run) >= 0.8
}

///|
/// Approval record that makes a model promotion auditable.
pub struct ReliabilityModelApproval {
  model_id : String
  from_stage : ReliabilityModelStage
  to_stage : ReliabilityModelStage
  approver : String
  approved_at : Double
  validation_run_id : String
  rationale : String
  expires_at : Double
}

///|
pub fn reliability_model_approval(
  model_id : String,
  from_stage : ReliabilityModelStage,
  to_stage : ReliabilityModelStage,
  approver : String,
  approved_at : Double,
  validation_run_id : String,
  rationale : String,
  expires_at : Double,
) -> ReliabilityModelApproval {
  if approved_at < 0.0 || expires_at < approved_at {
    abort("invalid model approval")
  }
  {
    model_id,
    from_stage,
    to_stage,
    approver,
    approved_at,
    validation_run_id,
    rationale,
    expires_at,
  }
}

///|
pub fn reliability_model_approval_is_current(
  approval : ReliabilityModelApproval,
  as_of : Double,
) -> Bool {
  as_of <= approval.expires_at
}

///|
pub fn reliability_model_approval_is_promotion(
  approval : ReliabilityModelApproval,
) -> Bool {
  approval.from_stage != approval.to_stage
}

///|
/// Evidence item attached to a governance review.
pub struct ReliabilityEvidence {
  evidence_id : String
  subject_id : String
  evidence_type : String
  source : String
  collected_at : Double
  quality : Double
  checksum : Double
  verified : Bool
}

///|
pub fn reliability_evidence(
  evidence_id : String,
  subject_id : String,
  evidence_type : String,
  source : String,
  collected_at : Double,
  quality : Double,
  checksum : Double,
  verified : Bool,
) -> ReliabilityEvidence {
  if collected_at < 0.0 || quality < 0.0 || quality > 1.0 {
    abort("invalid reliability evidence")
  }
  {
    evidence_id,
    subject_id,
    evidence_type,
    source,
    collected_at,
    quality,
    checksum,
    verified,
  }
}

///|
pub fn reliability_evidence_score(evidence : ReliabilityEvidence) -> Double {
  evidence.quality * (if evidence.verified { 1.0 } else { 0.5 })
}

///|
pub fn reliability_evidence_is_acceptable(
  evidence : ReliabilityEvidence,
  threshold : Double,
) -> Bool {
  reliability_evidence_score(evidence) >= threshold
}

///|
pub fn reliability_evidence_subject_score(
  evidence : Array[ReliabilityEvidence],
  subject_id : String,
) -> Double {
  let selected = evidence.filter(item => item.subject_id == subject_id)
  if selected.is_empty() {
    0.0
  } else {
    selected.fold(init=0.0, (sum, item) => {
      sum + reliability_evidence_score(item)
    }) /
    selected.length().to_double()
  }
}

///|
pub fn reliability_evidence_unverified_ids(
  evidence : Array[ReliabilityEvidence],
) -> Array[String] {
  evidence.filter_map(item => {
    if item.verified {
      None
    } else {
      Some(item.evidence_id)
    }
  })
}

///|
/// Change request for a reliability calculation or policy.
pub struct ReliabilityChangeRequest {
  change_id : String
  subject_id : String
  requester : String
  description : String
  impact : Double
  risk_score : Double
  requested_at : Double
  due_at : Double
  approved : Bool
  implemented : Bool
  verified : Bool
}

///|
pub fn reliability_change_request(
  change_id : String,
  subject_id : String,
  requester : String,
  description : String,
  impact : Double,
  risk_score : Double,
  requested_at : Double,
  due_at : Double,
  approved : Bool,
  implemented : Bool,
  verified : Bool,
) -> ReliabilityChangeRequest {
  if impact < 0.0 ||
    risk_score < 0.0 ||
    requested_at < 0.0 ||
    due_at < requested_at ||
    (verified && !implemented) {
    abort("invalid reliability change request")
  }
  {
    change_id,
    subject_id,
    requester,
    description,
    impact,
    risk_score,
    requested_at,
    due_at,
    approved,
    implemented,
    verified,
  }
}

///|
pub fn reliability_change_is_releasable(
  change : ReliabilityChangeRequest,
) -> Bool {
  change.approved && change.implemented && change.verified
}

///|
pub fn reliability_change_is_overdue(
  change : ReliabilityChangeRequest,
  as_of : Double,
) -> Bool {
  !reliability_change_is_releasable(change) && as_of > change.due_at
}

///|
pub fn reliability_change_priority(change : ReliabilityChangeRequest) -> Double {
  change.impact * (1.0 + change.risk_score)
}

///|
/// Governance snapshot assembled for a release decision.
pub struct ReliabilityGovernanceSnapshot {
  as_of : Double
  model_count : Int
  deployable_models : Int
  expired_models : Int
  validation_count : Int
  failed_validations : Int
  evidence_score : Double
  open_changes : Int
  overdue_changes : Int
  readiness : Double
}

///|
pub fn reliability_governance_snapshot(
  as_of : Double,
  models : Array[ReliabilityModelRecord],
  validations : Array[ReliabilityValidationRun],
  evidence : Array[ReliabilityEvidence],
  changes : Array[ReliabilityChangeRequest],
) -> ReliabilityGovernanceSnapshot {
  let deployable = models
    .filter(model => reliability_model_is_deployable(model, as_of))
    .length()
  let expired = models
    .filter(model => reliability_model_is_expired(model, as_of))
    .length()
  let failed = validations
    .filter(run => run.status is ReliabilityValidationFailed)
    .length()
  let open_changes = changes
    .filter(change => !reliability_change_is_releasable(change))
    .length()
  let overdue = changes
    .filter(change => reliability_change_is_overdue(change, as_of))
    .length()
  let evidence_score = if evidence.is_empty() {
    1.0
  } else {
    evidence.fold(init=0.0, (sum, item) => {
      sum + reliability_evidence_score(item)
    }) /
    evidence.length().to_double()
  }
  let validation_score = if validations.is_empty() {
    1.0
  } else {
    validations.fold(init=0.0, (sum, run) => {
      sum + reliability_validation_score(run)
    }) /
    validations.length().to_double()
  }
  let change_score = if changes.is_empty() {
    1.0
  } else {
    (changes.length() - overdue).to_double() / changes.length().to_double()
  }
  let readiness = (0.4 * evidence_score +
    0.4 * validation_score +
    0.2 * change_score)
    .min(1.0)
    .max(0.0)
  {
    as_of,
    model_count: models.length(),
    deployable_models: deployable,
    expired_models: expired,
    validation_count: validations.length(),
    failed_validations: failed,
    evidence_score,
    open_changes,
    overdue_changes: overdue,
    readiness,
  }
}

///|
pub fn reliability_governance_is_ready(
  snapshot : ReliabilityGovernanceSnapshot,
) -> Bool {
  snapshot.readiness >= 0.8 &&
  snapshot.failed_validations == 0 &&
  snapshot.overdue_changes == 0
}

///|
pub fn reliability_governance_blockers(
  snapshot : ReliabilityGovernanceSnapshot,
) -> Array[String] {
  let blockers = Array::new()
  if snapshot.failed_validations > 0 {
    blockers.push("failed validation runs")
  }
  if snapshot.expired_models > 0 {
    blockers.push("expired model approvals")
  }
  if snapshot.overdue_changes > 0 {
    blockers.push("overdue change requests")
  }
  if snapshot.evidence_score < 0.8 {
    blockers.push("insufficient evidence quality")
  }
  blockers
}

///|
pub fn reliability_governance_checksum(
  snapshot : ReliabilityGovernanceSnapshot,
  models : Array[ReliabilityModelRecord],
) -> Double {
  snapshot.readiness * 100.0 +
  snapshot.model_count.to_double() +
  snapshot.validation_count.to_double() +
  models.fold(init=0.0, (sum, model) => sum + reliability_model_checksum(model))
}
