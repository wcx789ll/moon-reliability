///|
/// Data-cleaning report for reliability observations.
pub struct DataQualityReport {
  input_count : Int
  valid_count : Int
  invalid_count : Int
  duplicate_count : Int
  negative_count : Int
  zero_count : Int
  warnings : Array[String]
}

///|
pub fn data_quality_report(
  input_count~ : Int,
  valid_count~ : Int,
  invalid_count~ : Int,
  duplicate_count~ : Int,
  negative_count~ : Int,
  zero_count~ : Int,
  warnings~ : Array[String],
) -> DataQualityReport {
  {
    input_count,
    valid_count,
    invalid_count,
    duplicate_count,
    negative_count,
    zero_count,
    warnings,
  }
}

///|
pub fn inspect_times(times : Array[Double]) -> DataQualityReport {
  let warnings : Array[String] = []
  let mut negative = 0
  let mut zero = 0
  let mut duplicates = 0
  let sorted = times.copy()
  sorted.sort()
  for i in 0..<times.length() {
    if times[i] < 0.0 {
      negative += 1
    }
    if times[i] == 0.0 {
      zero += 1
    }
  }
  for i in 1..<sorted.length() {
    if sorted[i] == sorted[i - 1] {
      duplicates += 1
    }
  }
  if negative > 0 {
    warnings.push("negative times found")
  }
  if zero > 0 {
    warnings.push("zero times require special PDF handling")
  }
  if duplicates > 0 {
    warnings.push("tied event times found; use a tied-risk estimator")
  }
  data_quality_report(
    input_count=times.length(),
    valid_count=times.length() - negative,
    invalid_count=negative,
    duplicate_count=duplicates,
    negative_count=negative,
    zero_count=zero,
    warnings~,
  )
}

///|
pub fn winsorize(
  values : Array[Double],
  lower_probability : Double,
  upper_probability : Double,
) -> Array[Double] {
  if lower_probability < 0.0 ||
    upper_probability > 1.0 ||
    lower_probability >= upper_probability {
    abort("invalid winsorization probabilities")
  }
  let lower = quantile(values, lower_probability)
  let upper = quantile(values, upper_probability)
  values.map(value => value.max(lower).min(upper))
}

///|
pub fn remove_nonpositive(values : Array[Double]) -> Array[Double] {
  values.filter(value => value > 0.0)
}

///|
pub fn impute_right_censoring(
  times : Array[Double],
  censor_time : Double,
) -> Array[LifeObservation] {
  times.map(time => {
    if time <= censor_time {
      failure(time)
    } else {
      right_censored(censor_time)
    }
  })
}

///|
pub fn merge_observations(
  first : Array[LifeObservation],
  second : Array[LifeObservation],
) -> Array[LifeObservation] {
  let result = first.copy()
  for record in second {
    result.push(record)
  }
  sort_observations(result)
}

///|
pub fn stratify_observations(
  records : Array[LifeObservation],
  strata : Array[Int],
) -> Map[Int, Array[LifeObservation]] {
  if records.length() != strata.length() {
    abort("strata length mismatch")
  }
  let result : Map[Int, Array[LifeObservation]] = Map([])
  for i in 0..<records.length() {
    let bucket = result.get_or_init(strata[i], () => [])
    bucket.push(records[i])
  }
  result
}
