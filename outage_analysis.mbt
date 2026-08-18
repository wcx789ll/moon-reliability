///|
/// Customer outage record used for utility-style reliability metrics.
pub struct OutageRecord {
  customer : Int
  start : Double
  duration : Double
  customers_affected : Int
  cause : Int
}

///|
pub fn outage_record(
  customer~ : Int,
  start~ : Double,
  duration~ : Double,
  customers_affected~ : Int,
  cause~ : Int,
) -> OutageRecord {
  if customer < 0 || start < 0.0 || duration < 0.0 || customers_affected <= 0 {
    abort("invalid outage record")
  }
  { customer, start, duration, customers_affected, cause }
}

///|
pub struct OutageMetrics {
  saidi : Double
  saifi : Double
  caidi : Double
  asai : Double
  maifi : Double
  total_customer_interruptions : Int
}

///|
pub fn outage_metrics(
  saidi~ : Double,
  saifi~ : Double,
  caidi~ : Double,
  asai~ : Double,
  maifi~ : Double,
  total_customer_interruptions~ : Int,
) -> OutageMetrics {
  { saidi, saifi, caidi, asai, maifi, total_customer_interruptions }
}

///|
pub fn calculate_outage_metrics(
  outages : Array[OutageRecord],
  customers : Int,
  observation_window : Double,
) -> OutageMetrics {
  if customers <= 0 || observation_window <= 0.0 {
    abort("invalid outage population")
  }
  let total_minutes = outages.fold(init=0.0, (sum, outage) => {
    sum + outage.duration * outage.customers_affected.to_double()
  })
  let interruptions = outages.fold(init=0, (sum, outage) => {
    sum + outage.customers_affected
  })
  let saidi = total_minutes / customers.to_double()
  let saifi = interruptions.to_double() / customers.to_double()
  let caidi = if interruptions == 0 {
    0.0
  } else {
    total_minutes / interruptions.to_double()
  }
  let asai = 1.0 - saidi / (observation_window * 60.0)
  let momentary = outages.filter(outage => outage.duration < 5.0).length()
  let maifi = momentary.to_double() / customers.to_double()
  outage_metrics(
    saidi~,
    saifi~,
    caidi~,
    asai~,
    maifi~,
    total_customer_interruptions=interruptions,
  )
}

///|
pub fn outage_cause_counts(outages : Array[OutageRecord]) -> Map[Int, Int] {
  let result : Map[Int, Int] = Map([])
  for outage in outages {
    result.update_or_default(outage.cause, 1, old => old + 1)
  }
  result
}

///|
pub fn restoration_curve(
  outages : Array[OutageRecord],
  grid : Array[Double],
) -> Array[Double] {
  grid.map(time => {
    let remaining = outages.fold(init=0, (sum, outage) => {
      if outage.start <= time && outage.start + outage.duration > time {
        sum + outage.customers_affected
      } else {
        sum
      }
    })
    remaining.to_double()
  })
}

///|
pub fn outage_quantiles(
  outages : Array[OutageRecord],
  probabilities : Array[Double],
) -> Array[Double] {
  let durations = outages.map(outage => outage.duration)
  probabilities.map(p => quantile(durations, p))
}

///|
pub fn longest_outage(outages : Array[OutageRecord]) -> OutageRecord {
  if outages.is_empty() {
    abort("longest outage requires records")
  }
  let mut best = outages[0]
  for outage in outages {
    if outage.duration > best.duration {
      best = outage
    }
  }
  best
}

///|
pub fn outage_rate(outages : Array[OutageRecord], window : Double) -> Double {
  if window <= 0.0 {
    abort("window must be positive")
  }
  outages.length().to_double() / window
}
