///|
/// Operational health score assembled from reliability indicators.
pub struct ReliabilityScorecard {
  reliability_score : Double
  availability_score : Double
  quality_score : Double
  maintenance_score : Double
  overall_score : Double
  grade : String
  recommendations : Array[String]
}

///|
pub fn reliability_scorecard(
  reliability_score~ : Double,
  availability_score~ : Double,
  quality_score~ : Double,
  maintenance_score~ : Double,
  overall_score~ : Double,
  grade~ : String,
  recommendations~ : Array[String],
) -> ReliabilityScorecard {
  {
    reliability_score,
    availability_score,
    quality_score,
    maintenance_score,
    overall_score,
    grade,
    recommendations,
  }
}

///|
pub fn build_scorecard(
  model : ReliabilityModel,
  observed_availability : Double,
  defect_rate_value : Double,
  maintenance_compliance : Double,
  horizon : Double,
) -> ReliabilityScorecard {
  let reliability = model.survival(horizon).max(0.0).min(1.0)
  let availability = observed_availability.max(0.0).min(1.0)
  let quality = (1.0 - defect_rate_value).max(0.0).min(1.0)
  let maintenance = maintenance_compliance.max(0.0).min(1.0)
  let overall = 0.4 * reliability +
    0.3 * availability +
    0.2 * quality +
    0.1 * maintenance
  let recommendations : Array[String] = []
  if reliability < 0.9 {
    recommendations.push("review lifetime distribution and wear-out drivers")
  }
  if availability < 0.99 {
    recommendations.push("reduce repair duration or improve spare coverage")
  }
  if quality < 0.98 {
    recommendations.push("investigate defect and early-failure population")
  }
  if maintenance < 0.9 {
    recommendations.push("close overdue preventive-maintenance work")
  }
  reliability_scorecard(
    reliability_score=reliability,
    availability_score=availability,
    quality_score=quality,
    maintenance_score=maintenance,
    overall_score=overall,
    grade=score_grade(overall),
    recommendations~,
  )
}

///|
pub fn score_grade(score : Double) -> String {
  if score >= 0.95 {
    "A"
  } else if score >= 0.85 {
    "B"
  } else if score >= 0.70 {
    "C"
  } else if score >= 0.50 {
    "D"
  } else {
    "E"
  }
}

///|
pub fn score_trend(
  previous : ReliabilityScorecard,
  current : ReliabilityScorecard,
) -> Double {
  current.overall_score - previous.overall_score
}

///|
pub fn indicator_weighted_score(
  values : Array[Double],
  weights : Array[Double],
) -> Double {
  weighted_mean(values, weights)
}

///|
pub fn scorecard_risk_flag(
  scorecard : ReliabilityScorecard,
  threshold : Double,
) -> Bool {
  scorecard.overall_score < threshold
}

///|
pub fn recommendation_count(scorecard : ReliabilityScorecard) -> Int {
  scorecard.recommendations.length()
}
