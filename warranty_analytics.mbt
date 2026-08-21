///|
/// Warranty coverage policy for a product family.
pub struct ReliabilityWarranty {
  warranty_id : String
  product_code : String
  start_age : Double
  end_age : Double
  deductible : Double
  labor_rate : Double
  parts_markup : Double
  transfer_allowed : Bool
}

///|
pub fn reliability_warranty(
  warranty_id : String,
  product_code : String,
  start_age : Double,
  end_age : Double,
  deductible : Double,
  labor_rate : Double,
  parts_markup : Double,
  transfer_allowed : Bool,
) -> ReliabilityWarranty {
  if start_age < 0.0 ||
    end_age <= start_age ||
    deductible < 0.0 ||
    labor_rate < 0.0 ||
    parts_markup < 0.0 {
    abort("invalid warranty policy")
  }
  {
    warranty_id,
    product_code,
    start_age,
    end_age,
    deductible,
    labor_rate,
    parts_markup,
    transfer_allowed,
  }
}

///|
pub fn reliability_warranty_is_active(
  warranty : ReliabilityWarranty,
  age : Double,
) -> Bool {
  age >= warranty.start_age && age <= warranty.end_age
}

///|
pub fn reliability_warranty_remaining(
  warranty : ReliabilityWarranty,
  age : Double,
) -> Double {
  (warranty.end_age - age).max(0.0)
}

///|
pub fn reliability_warranty_coverage_fraction(
  warranty : ReliabilityWarranty,
  age : Double,
) -> Double {
  if age <= warranty.start_age {
    1.0
  } else if age >= warranty.end_age {
    0.0
  } else {
    (warranty.end_age - age) / (warranty.end_age - warranty.start_age)
  }
}

///|
/// A warranty claim with failure cause and service outcome.
pub struct ReliabilityWarrantyClaim {
  claim_id : Int
  asset_id : Int
  warranty_id : String
  age : Double
  opened_at : Double
  closed_at : Double
  part_cost : Double
  labor_hours : Double
  repeat_claim : Bool
  accepted : Bool
  severity : Double
}

///|
pub fn reliability_warranty_claim(
  claim_id : Int,
  asset_id : Int,
  warranty_id : String,
  age : Double,
  opened_at : Double,
  closed_at : Double,
  part_cost : Double,
  labor_hours : Double,
  repeat_claim : Bool,
  accepted : Bool,
  severity : Double,
) -> ReliabilityWarrantyClaim {
  if claim_id < 0 ||
    asset_id < 0 ||
    age < 0.0 ||
    closed_at < opened_at ||
    part_cost < 0.0 ||
    labor_hours < 0.0 ||
    severity < 0.0 {
    abort("invalid warranty claim")
  }
  {
    claim_id,
    asset_id,
    warranty_id,
    age,
    opened_at,
    closed_at,
    part_cost,
    labor_hours,
    repeat_claim,
    accepted,
    severity,
  }
}

///|
pub fn reliability_warranty_claim_cycle_time(
  claim : ReliabilityWarrantyClaim,
) -> Double {
  claim.closed_at - claim.opened_at
}

///|
pub fn reliability_warranty_claim_cost(
  warranty : ReliabilityWarranty,
  claim : ReliabilityWarrantyClaim,
) -> Double {
  if !claim.accepted {
    0.0
  } else {
    warranty.deductible +
    claim.part_cost * (1.0 + warranty.parts_markup) +
    claim.labor_hours * warranty.labor_rate
  }
}

///|
pub fn reliability_warranty_claim_is_repeat(
  claim : ReliabilityWarrantyClaim,
) -> Bool {
  claim.repeat_claim
}

///|
pub fn reliability_warranty_claim_is_late(
  claim : ReliabilityWarrantyClaim,
  service_limit : Double,
) -> Bool {
  service_limit >= 0.0 &&
  reliability_warranty_claim_cycle_time(claim) > service_limit
}

///|
/// Cohort-level warranty experience and actuarial reserve.
pub struct ReliabilityWarrantyCohort {
  cohort_id : Int
  product_code : String
  population : Int
  exposure : Double
  claims : Array[ReliabilityWarrantyClaim]
  average_price : Double
  reserve_rate : Double
}

///|
pub fn reliability_warranty_cohort(
  cohort_id : Int,
  product_code : String,
  population : Int,
  exposure : Double,
  claims : Array[ReliabilityWarrantyClaim],
  average_price : Double,
  reserve_rate : Double,
) -> ReliabilityWarrantyCohort {
  if cohort_id < 0 ||
    population < 0 ||
    exposure < 0.0 ||
    average_price < 0.0 ||
    reserve_rate < 0.0 {
    abort("invalid warranty cohort")
  }
  {
    cohort_id,
    product_code,
    population,
    exposure,
    claims,
    average_price,
    reserve_rate,
  }
}

///|
pub fn reliability_warranty_cohort_claim_count(
  cohort : ReliabilityWarrantyCohort,
) -> Int {
  cohort.claims.length()
}

///|
pub fn reliability_warranty_cohort_accepted_claims(
  cohort : ReliabilityWarrantyCohort,
) -> Int {
  cohort.claims.fold(init=0, (count, claim) => {
    if claim.accepted {
      count + 1
    } else {
      count
    }
  })
}

///|
pub fn reliability_warranty_cohort_repeat_claims(
  cohort : ReliabilityWarrantyCohort,
) -> Int {
  cohort.claims.fold(init=0, (count, claim) => {
    if claim.repeat_claim {
      count + 1
    } else {
      count
    }
  })
}

///|
pub fn reliability_warranty_cohort_claim_rate(
  cohort : ReliabilityWarrantyCohort,
) -> Double {
  if cohort.population == 0 {
    0.0
  } else {
    reliability_warranty_cohort_accepted_claims(cohort).to_double() /
    cohort.population.to_double()
  }
}

///|
pub fn reliability_warranty_cohort_repeat_rate(
  cohort : ReliabilityWarrantyCohort,
) -> Double {
  let accepted = reliability_warranty_cohort_accepted_claims(cohort)
  if accepted == 0 {
    0.0
  } else {
    reliability_warranty_cohort_repeat_claims(cohort).to_double() /
    accepted.to_double()
  }
}

///|
pub fn reliability_warranty_cohort_cost(
  cohort : ReliabilityWarrantyCohort,
  warranty : ReliabilityWarranty,
) -> Double {
  cohort.claims.fold(init=0.0, (sum, claim) => {
    sum + reliability_warranty_claim_cost(warranty, claim)
  })
}

///|
pub fn reliability_warranty_cohort_cost_per_unit(
  cohort : ReliabilityWarrantyCohort,
  warranty : ReliabilityWarranty,
) -> Double {
  if cohort.population == 0 {
    0.0
  } else {
    reliability_warranty_cohort_cost(cohort, warranty) /
    cohort.population.to_double()
  }
}

///|
pub fn reliability_warranty_cohort_expected_reserve(
  cohort : ReliabilityWarrantyCohort,
  warranty : ReliabilityWarranty,
) -> Double {
  let incurred = reliability_warranty_cohort_cost(cohort, warranty)
  let earned = cohort.population.to_double() *
    cohort.average_price *
    cohort.reserve_rate
  (earned - incurred).max(0.0)
}

///|
pub fn reliability_warranty_cohort_loss_ratio(
  cohort : ReliabilityWarrantyCohort,
  warranty : ReliabilityWarranty,
) -> Double {
  let earned = cohort.population.to_double() * cohort.average_price
  if earned == 0.0 {
    0.0
  } else {
    reliability_warranty_cohort_cost(cohort, warranty) / earned
  }
}

///|
pub fn reliability_warranty_cohort_average_cycle_time(
  cohort : ReliabilityWarrantyCohort,
) -> Double {
  if cohort.claims.is_empty() {
    0.0
  } else {
    cohort.claims.fold(init=0.0, (sum, claim) => {
      sum + reliability_warranty_claim_cycle_time(claim)
    }) /
    cohort.claims.length().to_double()
  }
}

///|
pub fn reliability_warranty_cohort_severity(
  cohort : ReliabilityWarrantyCohort,
) -> Double {
  if cohort.claims.is_empty() {
    0.0
  } else {
    cohort.claims.fold(init=0.0, (sum, claim) => sum + claim.severity) /
    cohort.claims.length().to_double()
  }
}

///|
/// Age-bucketed claim experience for early-warning monitoring.
pub struct ReliabilityWarrantyAgeBand {
  lower_age : Double
  upper_age : Double
  claim_count : Int
  accepted_count : Int
  cost : Double
  exposure : Double
}

///|
pub fn reliability_warranty_age_band(
  lower_age : Double,
  upper_age : Double,
  claim_count : Int,
  accepted_count : Int,
  cost : Double,
  exposure : Double,
) -> ReliabilityWarrantyAgeBand {
  if lower_age < 0.0 ||
    upper_age <= lower_age ||
    claim_count < 0 ||
    accepted_count < 0 ||
    cost < 0.0 ||
    exposure < 0.0 {
    abort("invalid warranty age band")
  }
  { lower_age, upper_age, claim_count, accepted_count, cost, exposure }
}

///|
pub fn reliability_warranty_age_band_rate(
  band : ReliabilityWarrantyAgeBand,
) -> Double {
  if band.exposure == 0.0 {
    0.0
  } else {
    band.accepted_count.to_double() / band.exposure
  }
}

///|
pub fn reliability_warranty_age_band_cost_rate(
  band : ReliabilityWarrantyAgeBand,
) -> Double {
  if band.exposure == 0.0 {
    0.0
  } else {
    band.cost / band.exposure
  }
}

///|
pub fn reliability_warranty_age_band_midpoint(
  band : ReliabilityWarrantyAgeBand,
) -> Double {
  (band.lower_age + band.upper_age) / 2.0
}

///|
pub fn reliability_warranty_build_age_bands(
  warranty : ReliabilityWarranty,
  claims : Array[ReliabilityWarrantyClaim],
  width : Double,
) -> Array[ReliabilityWarrantyAgeBand] {
  if width <= 0.0 {
    abort("age band width must be positive")
  }
  let result = Array::new()
  let mut lower = warranty.start_age
  while lower < warranty.end_age {
    let upper = (lower + width).min(warranty.end_age)
    let selected = claims.filter(claim => {
      claim.age >= lower && claim.age < upper
    })
    let cost = selected.fold(init=0.0, (sum, claim) => {
      sum + claim.part_cost + claim.labor_hours * warranty.labor_rate
    })
    let accepted = selected.fold(init=0, (count, claim) => {
      if claim.accepted {
        count + 1
      } else {
        count
      }
    })
    result.push(
      reliability_warranty_age_band(
        lower,
        upper,
        selected.length(),
        accepted,
        cost,
        selected.length().to_double(),
      ),
    )
    lower = upper
  }
  result
}

///|
pub fn reliability_warranty_peak_age_band(
  bands : Array[ReliabilityWarrantyAgeBand],
) -> Int {
  if bands.is_empty() {
    return -1
  }
  let mut best = 0
  for i in 1..<bands.length() {
    if reliability_warranty_age_band_cost_rate(bands[i]) >
      reliability_warranty_age_band_cost_rate(bands[best]) {
      best = i
    }
  }
  best
}

///|
/// Forecast of future warranty liability from an empirical claim curve.
pub struct ReliabilityWarrantyForecast {
  horizon : Double
  expected_claims : Double
  expected_cost : Double
  lower_cost : Double
  upper_cost : Double
  confidence : Double
}

///|
pub fn reliability_warranty_forecast(
  horizon : Double,
  expected_claims : Double,
  expected_cost : Double,
  lower_cost : Double,
  upper_cost : Double,
  confidence : Double,
) -> ReliabilityWarrantyForecast {
  if horizon < 0.0 ||
    expected_claims < 0.0 ||
    expected_cost < 0.0 ||
    lower_cost < 0.0 ||
    upper_cost < lower_cost ||
    confidence <= 0.0 ||
    confidence >= 1.0 {
    abort("invalid warranty forecast")
  }
  {
    horizon,
    expected_claims,
    expected_cost,
    lower_cost,
    upper_cost,
    confidence,
  }
}

///|
pub fn reliability_warranty_forecast_margin(
  forecast : ReliabilityWarrantyForecast,
) -> Double {
  (forecast.upper_cost - forecast.lower_cost) / 2.0
}

///|
pub fn reliability_warranty_forecast_reserve(
  forecast : ReliabilityWarrantyForecast,
  safety_loading : Double,
) -> Double {
  if safety_loading < 0.0 {
    abort("safety loading must be non-negative")
  }
  forecast.upper_cost * (1.0 + safety_loading)
}

///|
/// Warranty model based on an age-dependent hazard curve.
pub struct ReliabilityWarrantyHazardCurve {
  ages : Array[Double]
  hazards : Array[Double]
  cumulative_claims : Array[Double]
}

///|
pub fn reliability_warranty_hazard_curve(
  ages : Array[Double],
  hazards : Array[Double],
) -> ReliabilityWarrantyHazardCurve {
  if ages.length() != hazards.length() || ages.is_empty() {
    abort("hazard curve arrays must be equal and non-empty")
  }
  let mut cumulative = 0.0
  let totals = Array::makei(ages.length(), i => {
    if hazards[i] < 0.0 {
      abort("hazard must be non-negative")
    }
    if i > 0 {
      cumulative += hazards[i] * (ages[i] - ages[i - 1]).max(0.0)
    }
    cumulative
  })
  { ages, hazards, cumulative_claims: totals }
}

///|
pub fn reliability_warranty_hazard_at(
  curve : ReliabilityWarrantyHazardCurve,
  age : Double,
) -> Double {
  if age <= curve.ages[0] {
    curve.hazards[0]
  } else {
    let mut selected = curve.hazards[curve.hazards.length() - 1]
    for i in 0..<curve.ages.length() {
      if age <= curve.ages[i] {
        selected = curve.hazards[i]
        return selected
      }
    }
    selected
  }
}

///|
pub fn reliability_warranty_cumulative_hazard_at(
  curve : ReliabilityWarrantyHazardCurve,
  age : Double,
) -> Double {
  if age <= curve.ages[0] {
    0.0
  } else {
    let mut total = curve.cumulative_claims[curve.cumulative_claims.length() - 1]
    for i in 1..<curve.ages.length() {
      if age <= curve.ages[i] {
        let width = curve.ages[i] - curve.ages[i - 1]
        let fraction = if width == 0.0 {
          0.0
        } else {
          (age - curve.ages[i - 1]) / width
        }
        total = curve.cumulative_claims[i - 1] +
          fraction * curve.hazards[i] * width
        return total
      }
    }
    total +
    curve.hazards[curve.hazards.length() - 1] *
    (age - curve.ages[curve.ages.length() - 1])
  }
}

///|
pub fn reliability_warranty_claim_probability(
  curve : ReliabilityWarrantyHazardCurve,
  age : Double,
) -> Double {
  1.0 - @math.exp(-reliability_warranty_cumulative_hazard_at(curve, age))
}

///|
pub fn reliability_warranty_survival_probability(
  curve : ReliabilityWarrantyHazardCurve,
  age : Double,
) -> Double {
  @math.exp(-reliability_warranty_cumulative_hazard_at(curve, age))
}

///|
pub fn reliability_warranty_expected_claim_cost(
  curve : ReliabilityWarrantyHazardCurve,
  warranty : ReliabilityWarranty,
  average_claim_cost : Double,
  population : Int,
) -> Double {
  if average_claim_cost < 0.0 || population < 0 {
    abort("invalid expected claim cost")
  }
  population.to_double() *
  reliability_warranty_claim_probability(curve, warranty.end_age) *
  average_claim_cost
}

///|
pub fn reliability_warranty_claim_cost_quantiles(
  curve : ReliabilityWarrantyHazardCurve,
  average_claim_cost : Double,
  population : Int,
  probabilities : Array[Double],
) -> Array[Double] {
  if average_claim_cost < 0.0 || population < 0 {
    abort("invalid claim cost quantile input")
  }
  probabilities.map(probability => {
    if probability <= 0.0 {
      0.0
    } else if probability >= 1.0 {
      population.to_double() * average_claim_cost
    } else {
      let claim_rate = reliability_warranty_claim_probability(
        curve,
        probability * curve.ages[curve.ages.length() - 1],
      )
      population.to_double() * average_claim_cost * claim_rate
    }
  })
}

///|
pub fn reliability_warranty_claim_checksum(
  cohort : ReliabilityWarrantyCohort,
  warranty : ReliabilityWarranty,
) -> Double {
  cohort.population.to_double() +
  cohort.exposure +
  reliability_warranty_cohort_cost(cohort, warranty) +
  reliability_warranty_cohort_claim_rate(cohort) * 100.0
}
