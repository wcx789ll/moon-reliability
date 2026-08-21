///|
/// Severity categories for a quantitative safety case.
pub(all) enum SafetySeverity {
  SafetyNegligible
  SafetyMinor
  SafetySerious
  SafetyCritical
  SafetyCatastrophic
} derive(Debug, Eq)

///|
pub(all) enum SafetyLikelihood {
  SafetyFrequent
  SafetyProbable
  SafetyOccasional
  SafetyRemote
  SafetyImprobable
} derive(Debug, Eq)

///|
pub struct SafetyHazard {
  hazard_id : Int
  title : String
  severity : SafetySeverity
  likelihood : SafetyLikelihood
  exposure : Double
  detectability : Double
  mitigated : Bool
  owner : Int
}

///|
pub fn safety_hazard(
  hazard_id : Int,
  title : String,
  severity : SafetySeverity,
  likelihood : SafetyLikelihood,
  exposure : Double,
  detectability : Double,
  mitigated : Bool,
  owner : Int,
) -> SafetyHazard {
  if hazard_id < 0 ||
    exposure < 0.0 ||
    detectability < 0.0 ||
    detectability > 1.0 ||
    owner < 0 {
    abort("invalid safety hazard")
  }
  {
    hazard_id,
    title,
    severity,
    likelihood,
    exposure,
    detectability,
    mitigated,
    owner,
  }
}

///|
pub fn safety_severity_score(severity : SafetySeverity) -> Int {
  match severity {
    SafetyNegligible => 1
    SafetyMinor => 2
    SafetySerious => 3
    SafetyCritical => 4
    SafetyCatastrophic => 5
  }
}

///|
pub fn safety_likelihood_score(likelihood : SafetyLikelihood) -> Int {
  match likelihood {
    SafetyFrequent => 5
    SafetyProbable => 4
    SafetyOccasional => 3
    SafetyRemote => 2
    SafetyImprobable => 1
  }
}

///|
pub fn safety_hazard_score(hazard : SafetyHazard) -> Double {
  safety_severity_score(hazard.severity).to_double() *
  safety_likelihood_score(hazard.likelihood).to_double() *
  hazard.exposure *
  (1.0 - hazard.detectability)
}

///|
pub fn safety_hazard_risk_class(hazard : SafetyHazard) -> String {
  let score = safety_hazard_score(hazard)
  if score >= 50.0 {
    "unacceptable"
  } else if score >= 20.0 {
    "tolerable-with-controls"
  } else {
    "broadly-acceptable"
  }
}

///|
pub fn safety_hazard_is_actionable(hazard : SafetyHazard) -> Bool {
  safety_hazard_score(hazard) >= 20.0 || !hazard.mitigated
}

///|
pub fn safety_hazard_residual_score(
  hazard : SafetyHazard,
  mitigation_effectiveness : Double,
) -> Double {
  if mitigation_effectiveness < 0.0 || mitigation_effectiveness > 1.0 {
    abort("mitigation effectiveness must be in [0, 1]")
  }
  safety_hazard_score(hazard) * (1.0 - mitigation_effectiveness)
}

///|
pub fn safety_hazard_expected_loss(
  hazard : SafetyHazard,
  consequence_cost : Double,
) -> Double {
  if consequence_cost < 0.0 {
    abort("consequence cost must be non-negative")
  }
  hazard.exposure * hazard.detectability * consequence_cost
}

///|
pub struct SafetyBarrier {
  barrier_id : Int
  hazard_id : Int
  name : String
  probability_of_success : Double
  independence : Double
  test_interval : Double
  last_test : Double
  failed : Bool
}

///|
pub fn safety_barrier(
  barrier_id : Int,
  hazard_id : Int,
  name : String,
  probability_of_success : Double,
  independence : Double,
  test_interval : Double,
  last_test : Double,
  failed : Bool,
) -> SafetyBarrier {
  if barrier_id < 0 ||
    hazard_id < 0 ||
    probability_of_success < 0.0 ||
    probability_of_success > 1.0 ||
    independence < 0.0 ||
    independence > 1.0 ||
    test_interval <= 0.0 ||
    last_test < 0.0 {
    abort("invalid safety barrier")
  }
  {
    barrier_id,
    hazard_id,
    name,
    probability_of_success,
    independence,
    test_interval,
    last_test,
    failed,
  }
}

///|
pub fn safety_barrier_is_due(barrier : SafetyBarrier, as_of : Double) -> Bool {
  as_of - barrier.last_test >= barrier.test_interval
}

///|
pub fn safety_barrier_effectiveness(barrier : SafetyBarrier) -> Double {
  if barrier.failed {
    0.0
  } else {
    barrier.probability_of_success
  }
}

///|
pub fn safety_barrier_common_cause_factor(barrier : SafetyBarrier) -> Double {
  1.0 - barrier.independence
}

///|
pub fn safety_barrier_retest(
  barrier : SafetyBarrier,
  as_of : Double,
  passed : Bool,
) -> SafetyBarrier {
  { ..barrier, last_test: as_of, failed: !passed }
}

///|
pub fn safety_barrier_failure_probability(barrier : SafetyBarrier) -> Double {
  1.0 - safety_barrier_effectiveness(barrier)
}

///|
pub fn safety_barrier_contribution(
  barrier : SafetyBarrier,
  hazard_exposure : Double,
) -> Double {
  hazard_exposure * safety_barrier_failure_probability(barrier)
}

///|
pub struct SafetyBarrierChain {
  hazard_id : Int
  barriers : Array[SafetyBarrier]
  architecture : String
  residual_probability : Double
  independence_penalty : Double
}

///|
pub fn safety_barrier_chain(
  hazard_id : Int,
  barriers : Array[SafetyBarrier],
  architecture : String,
) -> SafetyBarrierChain {
  if hazard_id < 0 ||
    barriers.is_empty() ||
    (architecture != "series" && architecture != "parallel") {
    abort("invalid barrier chain")
  }
  let effectiveness = barriers.map(barrier => {
    safety_barrier_effectiveness(barrier)
  })
  let residual = if architecture == "series" {
    allocation_series_failure_rate(effectiveness, 1.0)
  } else {
    allocation_parallel_failure_rate(effectiveness, 1.0)
  }
  let penalty = barriers.fold(init=0.0, (total, barrier) => {
      total + safety_barrier_common_cause_factor(barrier)
    }) /
    barriers.length().to_double()
  {
    hazard_id,
    barriers,
    architecture,
    residual_probability: residual * (1.0 + penalty),
    independence_penalty: penalty,
  }
}

///|
pub fn safety_barrier_chain_effectiveness(chain : SafetyBarrierChain) -> Double {
  (1.0 - chain.residual_probability).max(0.0).min(1.0)
}

///|
pub fn safety_barrier_chain_failure_probability(
  chain : SafetyBarrierChain,
) -> Double {
  chain.residual_probability.min(1.0)
}

///|
pub fn safety_barrier_chain_due_count(
  chain : SafetyBarrierChain,
  as_of : Double,
) -> Int {
  chain.barriers.fold(init=0, (count, barrier) => {
    if safety_barrier_is_due(barrier, as_of) {
      count + 1
    } else {
      count
    }
  })
}

///|
pub fn safety_barrier_chain_failed_count(chain : SafetyBarrierChain) -> Int {
  chain.barriers.fold(init=0, (count, barrier) => {
    if barrier.failed {
      count + 1
    } else {
      count
    }
  })
}

///|
pub fn safety_barrier_chain_score(chain : SafetyBarrierChain) -> Double {
  safety_barrier_chain_effectiveness(chain) / (1.0 + chain.independence_penalty)
}

///|
pub struct SafetyRequirement {
  requirement_id : Int
  title : String
  target_probability : Double
  verified : Bool
  evidence_strength : Double
  hazard_ids : Array[Int]
}

///|
pub fn safety_requirement(
  requirement_id : Int,
  title : String,
  target_probability : Double,
  verified : Bool,
  evidence_strength : Double,
  hazard_ids : Array[Int],
) -> SafetyRequirement {
  if requirement_id < 0 ||
    target_probability < 0.0 ||
    target_probability > 1.0 ||
    evidence_strength < 0.0 ||
    evidence_strength > 1.0 {
    abort("invalid safety requirement")
  }
  {
    requirement_id,
    title,
    target_probability,
    verified,
    evidence_strength,
    hazard_ids,
  }
}

///|
pub fn safety_requirement_passes(
  requirement : SafetyRequirement,
  measured_probability : Double,
) -> Bool {
  requirement.verified &&
  measured_probability <= requirement.target_probability &&
  requirement.evidence_strength >= 0.8
}

///|
pub fn safety_requirement_gap(
  requirement : SafetyRequirement,
  measured_probability : Double,
) -> Double {
  measured_probability - requirement.target_probability
}

///|
pub fn safety_requirement_evidence_gap(
  requirement : SafetyRequirement,
) -> Double {
  (0.8 - requirement.evidence_strength).max(0.0)
}

///|
pub fn safety_requirement_hazard_count(requirement : SafetyRequirement) -> Int {
  requirement.hazard_ids.length()
}

///|
pub fn safety_requirement_checksum(requirement : SafetyRequirement) -> Double {
  requirement.requirement_id.to_double() +
  requirement.target_probability +
  requirement.evidence_strength +
  requirement.hazard_ids.length().to_double()
}

///|
pub struct SafetyVerification {
  requirement_id : Int
  test_id : Int
  measured_probability : Double
  confidence : Double
  passed : Bool
  evidence : String
}

///|
pub fn safety_verification(
  requirement_id : Int,
  test_id : Int,
  measured_probability : Double,
  confidence : Double,
  passed : Bool,
  evidence : String,
) -> SafetyVerification {
  if requirement_id < 0 ||
    test_id < 0 ||
    measured_probability < 0.0 ||
    measured_probability > 1.0 ||
    confidence <= 0.0 ||
    confidence > 1.0 {
    abort("invalid safety verification")
  }
  {
    requirement_id,
    test_id,
    measured_probability,
    confidence,
    passed,
    evidence,
  }
}

///|
pub fn safety_verification_strength(
  verification : SafetyVerification,
) -> Double {
  verification.confidence * (if verification.passed { 1.0 } else { 0.0 })
}

///|
pub fn safety_verification_is_credible(
  verification : SafetyVerification,
  minimum_confidence : Double,
) -> Bool {
  verification.passed && verification.confidence >= minimum_confidence
}

///|
pub fn safety_verification_risk(verification : SafetyVerification) -> Double {
  verification.measured_probability * (1.0 - verification.confidence)
}

///|
pub struct SafetyCaseSummary {
  hazard_count : Int
  actionable_hazards : Int
  barrier_count : Int
  failed_barriers : Int
  requirement_count : Int
  verified_requirements : Int
  verification_count : Int
  evidence_score : Double
  residual_risk : Double
  status : String
}

///|
pub fn safety_case_summary(
  hazards : Array[SafetyHazard],
  chains : Array[SafetyBarrierChain],
  requirements : Array[SafetyRequirement],
  verifications : Array[SafetyVerification],
) -> SafetyCaseSummary {
  let actionable = hazards.fold(init=0, (count, hazard) => {
    if safety_hazard_is_actionable(hazard) {
      count + 1
    } else {
      count
    }
  })
  let barriers = chains.fold(init=0, (count, chain) => {
    count + chain.barriers.length()
  })
  let failed = chains.fold(init=0, (count, chain) => {
    count + safety_barrier_chain_failed_count(chain)
  })
  let verified = requirements.fold(init=0, (count, requirement) => {
    if requirement.verified {
      count + 1
    } else {
      count
    }
  })
  let evidence = if verifications.is_empty() {
    0.0
  } else {
    mean(
      verifications.map(verification => {
        safety_verification_strength(verification)
      }),
    )
  }
  let residual = chains.fold(init=0.0, (total, chain) => {
    total + safety_barrier_chain_failure_probability(chain)
  })
  {
    hazard_count: hazards.length(),
    actionable_hazards: actionable,
    barrier_count: barriers,
    failed_barriers: failed,
    requirement_count: requirements.length(),
    verified_requirements: verified,
    verification_count: verifications.length(),
    evidence_score: evidence,
    residual_risk: residual,
    status: if actionable == 0 &&
      failed == 0 &&
      verified == requirements.length() &&
      evidence >= 0.8 {
      "accepted"
    } else {
      "open"
    },
  }
}

///|
pub fn safety_case_is_accepted(summary : SafetyCaseSummary) -> Bool {
  summary.status == "accepted"
}

///|
pub fn safety_case_gap(summary : SafetyCaseSummary) -> Int {
  summary.actionable_hazards +
  summary.failed_barriers +
  summary.requirement_count -
  summary.verified_requirements
}

///|
pub fn safety_case_evidence_score(summary : SafetyCaseSummary) -> Double {
  summary.evidence_score
}

///|
pub fn safety_case_residual_risk(summary : SafetyCaseSummary) -> Double {
  summary.residual_risk
}

///|
pub fn safety_case_checksum(summary : SafetyCaseSummary) -> Double {
  summary.hazard_count.to_double() +
  summary.actionable_hazards.to_double() +
  summary.barrier_count.to_double() +
  summary.failed_barriers.to_double() +
  summary.requirement_count.to_double() +
  summary.verified_requirements.to_double() +
  summary.verification_count.to_double() +
  summary.evidence_score +
  summary.residual_risk
}

///|
pub fn safety_hazard_rank(hazards : Array[SafetyHazard]) -> Array[SafetyHazard] {
  let result = hazards.copy()
  result.sort_by((left, right) => {
    let l = safety_hazard_score(left)
    let r = safety_hazard_score(right)
    if l > r {
      -1
    } else if l < r {
      1
    } else {
      0
    }
  })
  result
}

///|
pub fn safety_hazard_scores(hazards : Array[SafetyHazard]) -> Array[Double] {
  hazards.map(hazard => safety_hazard_score(hazard))
}

///|
pub fn safety_hazard_total_exposure(hazards : Array[SafetyHazard]) -> Double {
  hazards.fold(init=0.0, (total, hazard) => total + hazard.exposure)
}

///|
pub fn safety_hazard_total_loss(
  hazards : Array[SafetyHazard],
  consequence_cost : Double,
) -> Double {
  hazards.fold(init=0.0, (total, hazard) => {
    total + safety_hazard_expected_loss(hazard, consequence_cost)
  })
}

///|
pub fn safety_hazard_residual_scores(
  hazards : Array[SafetyHazard],
  mitigation_effectiveness : Double,
) -> Array[Double] {
  hazards.map(hazard => {
    safety_hazard_residual_score(hazard, mitigation_effectiveness)
  })
}

///|
pub fn safety_hazard_unmitigated_count(hazards : Array[SafetyHazard]) -> Int {
  hazards.fold(init=0, (count, hazard) => {
    if hazard.mitigated {
      count
    } else {
      count + 1
    }
  })
}

///|
pub fn safety_barrier_effectiveness_curve(
  barriers : Array[SafetyBarrier],
) -> Array[Double] {
  barriers.map(barrier => safety_barrier_effectiveness(barrier))
}

///|
pub fn safety_barrier_due_fraction(
  barriers : Array[SafetyBarrier],
  as_of : Double,
) -> Double {
  if barriers.is_empty() {
    0.0
  } else {
    barriers
    .fold(init=0, (count, barrier) => {
      if safety_barrier_is_due(barrier, as_of) {
        count + 1
      } else {
        count
      }
    })
    .to_double() /
    barriers.length().to_double()
  }
}

///|
pub fn safety_barrier_failure_fraction(
  barriers : Array[SafetyBarrier],
) -> Double {
  if barriers.is_empty() {
    0.0
  } else {
    barriers
    .fold(init=0, (count, barrier) => {
      if barrier.failed {
        count + 1
      } else {
        count
      }
    })
    .to_double() /
    barriers.length().to_double()
  }
}

///|
pub fn safety_requirement_completion(
  requirements : Array[SafetyRequirement],
) -> Double {
  if requirements.is_empty() {
    1.0
  } else {
    requirements
    .fold(init=0, (count, requirement) => {
      if requirement.verified {
        count + 1
      } else {
        count
      }
    })
    .to_double() /
    requirements.length().to_double()
  }
}

///|
pub fn safety_verification_pass_rate(
  verifications : Array[SafetyVerification],
) -> Double {
  if verifications.is_empty() {
    0.0
  } else {
    verifications
    .fold(init=0, (count, verification) => {
      if verification.passed {
        count + 1
      } else {
        count
      }
    })
    .to_double() /
    verifications.length().to_double()
  }
}

///|
pub fn safety_verification_average_confidence(
  verifications : Array[SafetyVerification],
) -> Double {
  if verifications.is_empty() {
    0.0
  } else {
    mean(verifications.map(verification => verification.confidence))
  }
}

///|
pub fn safety_owner_ids(hazards : Array[SafetyHazard]) -> Array[Int] {
  let result = []
  for hazard in hazards {
    if !result.contains(hazard.owner) {
      result.push(hazard.owner)
    }
  }
  result.sort()
  result
}

///|
pub fn safety_owner_risk(hazards : Array[SafetyHazard], owner : Int) -> Double {
  hazards
  .filter(hazard => hazard.owner == owner)
  .fold(init=0.0, (total, hazard) => total + safety_hazard_score(hazard))
}

///|
pub fn safety_owner_risk_scores(hazards : Array[SafetyHazard]) -> Array[Double] {
  safety_owner_ids(hazards).map(owner => safety_owner_risk(hazards, owner))
}

///|
pub fn safety_owner_rank(hazards : Array[SafetyHazard]) -> Array[Int] {
  let ids = safety_owner_ids(hazards)
  ids.sort_by((left, right) => {
    let l = safety_owner_risk(hazards, left)
    let r = safety_owner_risk(hazards, right)
    if l > r {
      -1
    } else if l < r {
      1
    } else {
      0
    }
  })
  ids
}

///|
pub fn safety_case_priority(summary : SafetyCaseSummary) -> Double {
  summary.residual_risk +
  summary.actionable_hazards.to_double() +
  summary.failed_barriers.to_double()
}

///|
pub fn safety_case_label(summary : SafetyCaseSummary) -> String {
  if safety_case_is_accepted(summary) {
    "accepted"
  } else if safety_case_priority(summary) < 5.0 {
    "review"
  } else {
    "escalate"
  }
}

///|
pub fn safety_case_readiness(summary : SafetyCaseSummary) -> Double {
  let hazard_score = if summary.hazard_count == 0 {
    1.0
  } else {
    1.0 -
    summary.actionable_hazards.to_double() / summary.hazard_count.to_double()
  }
  let barrier_score = if summary.barrier_count == 0 {
    1.0
  } else {
    1.0 -
    summary.failed_barriers.to_double() / summary.barrier_count.to_double()
  }
  let requirement_score = if summary.requirement_count == 0 {
    1.0
  } else {
    summary.verified_requirements.to_double() /
    summary.requirement_count.to_double()
  }
  (0.35 * hazard_score + 0.35 * barrier_score + 0.30 * requirement_score).min(
    1.0,
  )
}

///|
pub fn safety_case_readiness_label(summary : SafetyCaseSummary) -> String {
  if safety_case_readiness(summary) >= 0.9 {
    "ready"
  } else if safety_case_readiness(summary) >= 0.7 {
    "conditional"
  } else {
    "not-ready"
  }
}
