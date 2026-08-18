///|
/// Return a complete descriptive summary for mixed failure/censoring data.
pub fn summarize(records : Array[LifeObservation]) -> SampleSummary {
  if records.is_empty() {
    return empty_sample_summary()
  }
  let times = records.map(record => record.time)
  let values = records.filter_map(record => {
    if record.is_failure() {
      Some(record.time)
    } else {
      None
    }
  })
  let failure_count = values.length()
  let count = records.length()
  let center = mean(times)
  let spread = if count > 1 { variance(times) } else { 0.0 }
  {
    count,
    failures: failure_count,
    censored: count - failure_count,
    total_weight: records.fold(init=0.0, (total, record) => {
      total + record.weight
    }),
    mean: center,
    variance: spread,
    standard_deviation: spread.sqrt(),
    minimum: min_value(times),
    maximum: max_value(times),
    median: quantile(times, 0.5),
  }
}

///|
pub fn covariance(left : Array[Double], right : Array[Double]) -> Double {
  if left.length() != right.length() || left.length() < 2 {
    abort("covariance requires equal arrays with at least two values")
  }
  let left_mean = mean(left)
  let right_mean = mean(right)
  let mut result = 0.0
  for i in 0..<left.length() {
    result += (left[i] - left_mean) * (right[i] - right_mean)
  }
  result / (left.length() - 1).to_double()
}

///|
pub fn correlation(left : Array[Double], right : Array[Double]) -> Double {
  let denominator = variance(left).sqrt() * variance(right).sqrt()
  if denominator == 0.0 {
    0.0
  } else {
    covariance(left, right) / denominator
  }
}

///|
pub fn central_moment(values : Array[Double], order : Int) -> Double {
  if values.is_empty() || order < 1 {
    abort("invalid central moment request")
  }
  let center = mean(values)
  let mut result = 0.0
  for value in values {
    result += @math.pow(value - center, order.to_double())
  }
  result / values.length().to_double()
}

///|
pub fn skewness(values : Array[Double]) -> Double {
  let sd = variance(values).sqrt()
  if sd == 0.0 {
    0.0
  } else {
    central_moment(values, 3) / @math.pow(sd, 3.0)
  }
}

///|
pub fn excess_kurtosis(values : Array[Double]) -> Double {
  let sd = variance(values).sqrt()
  if sd == 0.0 {
    0.0
  } else {
    central_moment(values, 4) / @math.pow(sd, 4.0) - 3.0
  }
}

///|
pub fn trimmed_mean(values : Array[Double], trim_fraction : Double) -> Double {
  if trim_fraction < 0.0 || trim_fraction >= 0.5 {
    abort("trim_fraction must be in [0, 0.5)")
  }
  let sorted = values.copy()
  sorted.sort()
  let cut = (values.length().to_double() * trim_fraction).floor().to_int()
  let kept = sorted[cut:sorted.length() - cut].to_owned()
  mean(kept)
}

///|
pub fn median_absolute_deviation(values : Array[Double]) -> Double {
  let center = quantile(values, 0.5)
  quantile(values.map(value => (value - center).abs()), 0.5)
}

///|
pub fn rank_values(values : Array[Double]) -> Array[Double] {
  let indexed = Array::makei(values.length(), i => (values[i], i))
  indexed.sort_by((a, b) => {
    if a.0 < b.0 {
      -1
    } else if a.0 > b.0 {
      1
    } else {
      0
    }
  })
  let result = Array::make(values.length(), 0.0)
  let mut i = 0
  while i < indexed.length() {
    let mut end = i + 1
    while end < indexed.length() && indexed[end].0 == indexed[i].0 {
      end += 1
    }
    let rank = (i + end - 1).to_double() / 2.0 + 1.0
    for j in i..<end {
      result[indexed[j].1] = rank
    }
    i = end
  }
  result
}

///|
pub fn weighted_quantile(
  values : Array[Double],
  weights : Array[Double],
  p : Double,
) -> Double {
  if values.length() != weights.length() || values.is_empty() {
    abort("weighted quantile requires equal non-empty arrays")
  }
  if p < 0.0 || p > 1.0 {
    abort("p must be in [0, 1]")
  }
  let pairs = Array::makei(values.length(), i => (values[i], weights[i]))
  pairs.sort_by((a, b) => if a.0 < b.0 { -1 } else if a.0 > b.0 { 1 } else { 0 })
  let total = weights.fold(init=0.0, (s, w) => s + w)
  let target = p * total
  let mut cumulative = 0.0
  for _, pair in pairs {
    cumulative += pair.1
    if cumulative >= target {
      return pair.0
    }
  }
  pairs[pairs.length() - 1].0
}

///|
pub fn lag(
  values : Array[Double],
  offset : Int,
) -> (Array[Double], Array[Double]) {
  if offset < 0 || offset >= values.length() {
    abort("lag offset outside data")
  }
  (values[offset:].to_owned(), values[:values.length() - offset].to_owned())
}

///|
pub fn autocorrelation(values : Array[Double], offset : Int) -> Double {
  let (current, previous) = lag(values, offset)
  correlation(current, previous)
}

///|
pub fn moving_average(values : Array[Double], window : Int) -> Array[Double] {
  if window <= 0 || window > values.length() {
    abort("invalid moving-average window")
  }
  Array::makei(values.length() - window + 1, i => {
    mean(values[i:i + window].to_owned())
  })
}

///|
pub fn moving_standard_deviation(
  values : Array[Double],
  window : Int,
) -> Array[Double] {
  if window <= 1 || window > values.length() {
    abort("invalid moving standard deviation window")
  }
  Array::makei(values.length() - window + 1, i => {
    variance(values[i:i + window].to_owned()).sqrt()
  })
}

///|
pub fn geometric_mean(values : Array[Double]) -> Double {
  if values.is_empty() {
    abort("geometric mean requires data")
  }
  @math.exp(mean(values.map(value => @math.ln(value))))
}

///|
pub fn harmonic_mean(values : Array[Double]) -> Double {
  if values.is_empty() {
    abort("harmonic mean requires data")
  }
  values.length().to_double() /
  values.fold(init=0.0, (s, value) => s + 1.0 / value)
}
