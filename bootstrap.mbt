///|
/// Bootstrap distribution and confidence interval.
pub struct BootstrapResult {
  estimates : Array[Double]
  estimate : Double
  bias : Double
  standard_error : Double
  lower : Double
  upper : Double
  confidence_level : Double
}

///|
pub fn bootstrap_result(
  estimates~ : Array[Double],
  estimate~ : Double,
  bias~ : Double,
  standard_error~ : Double,
  lower~ : Double,
  upper~ : Double,
  confidence_level~ : Double,
) -> BootstrapResult {
  { estimates, estimate, bias, standard_error, lower, upper, confidence_level }
}

///|
pub fn bootstrap_mean(
  values : Array[Double],
  replications : Int,
  seed : Int,
  confidence_level : Double,
) -> BootstrapResult {
  bootstrap_statistic(values, replications, seed, confidence_level, sample => {
    mean(sample)
  })
}

///|
pub fn bootstrap_median(
  values : Array[Double],
  replications : Int,
  seed : Int,
  confidence_level : Double,
) -> BootstrapResult {
  bootstrap_statistic(values, replications, seed, confidence_level, sample => {
    quantile(sample, 0.5)
  })
}

///|
pub fn bootstrap_statistic(
  values : Array[Double],
  replications : Int,
  seed : Int,
  confidence_level : Double,
  statistic : (Array[Double]) -> Double,
) -> BootstrapResult {
  if values.is_empty() || replications < 2 {
    abort("bootstrap requires data and two replications")
  }
  if confidence_level <= 0.0 || confidence_level >= 1.0 {
    abort("invalid confidence level")
  }
  let state = RandomState::new(seed)
  let estimates = Array::makei(replications, _ => {
    let sample = Array::makei(values.length(), _ => {
      values[state.next_int().abs() % values.length()]
    })
    statistic(sample)
  })
  let estimate = statistic(values)
  let bias = mean(estimates) - estimate
  let error = variance(estimates).sqrt()
  let alpha = (1.0 - confidence_level) / 2.0
  bootstrap_result(
    estimates~,
    estimate~,
    bias~,
    standard_error=error,
    lower=quantile(estimates, alpha),
    upper=quantile(estimates, 1.0 - alpha),
    confidence_level~,
  )
}

///|
pub fn jackknife(
  values : Array[Double],
  statistic : (Array[Double]) -> Double,
) -> BootstrapResult {
  if values.length() < 3 {
    abort("jackknife requires three values")
  }
  let estimates = Array::makei(values.length(), i => {
    let sample : Array[Double] = []
    for j in 0..<values.length() {
      if i != j {
        sample.push(values[j])
      }
    }
    statistic(sample)
  })
  let estimate = mean(estimates)
  let bias = (values.length() - 1).to_double() * (estimate - statistic(values))
  let standard_error = ((values.length() - 1).to_double() /
  values.length().to_double() *
  estimates.fold(init=0.0, (sum, value) => {
    sum + (value - estimate) * (value - estimate)
  })).sqrt()
  bootstrap_result(
    estimates~,
    estimate=statistic(values),
    bias~,
    standard_error~,
    lower=estimate - 1.96 * standard_error,
    upper=estimate + 1.96 * standard_error,
    confidence_level=0.95,
  )
}

///|
pub fn bootstrap_reliability(
  records : Array[LifeObservation],
  time : Double,
  replications : Int,
  seed : Int,
) -> BootstrapResult {
  let statistic = sample => {
    let curve = kaplan_meier(sample)
    curve.survival_at(time)
  }
  let times = records.map(record => record.time)
  let result = bootstrap_statistic(times, replications, seed, 0.95, _ => {
    let sample_records = Array::makei(records.length(), i => {
      if times[i] <= time {
        failure(times[i])
      } else {
        right_censored(times[i])
      }
    })
    statistic(sample_records)
  })
  result
}

///|
pub fn bootstrap_standard_error(result : BootstrapResult) -> Double {
  result.standard_error
}
