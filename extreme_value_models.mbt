///|
/// Extreme-value distribution used for load, temperature, and stress maxima.
pub(all) enum ExtremeValueLaw {
  ExtremeGumbel
  ExtremeFrechet
  ExtremeWeibull
} derive(Debug, Eq)

///|
pub struct ExtremeValueModel {
  law : ExtremeValueLaw
  location : Double
  scale : Double
  shape : Double
  threshold : Double
  name : String
}

///|
pub fn extreme_value_model(
  law : ExtremeValueLaw,
  location : Double,
  scale : Double,
  shape : Double,
  threshold : Double,
  name : String,
) -> ExtremeValueModel {
  if scale <= 0.0 {
    abort("extreme-value scale must be positive")
  }
  { law, location, scale, shape, threshold, name }
}

///|
pub fn extreme_standardize(model : ExtremeValueModel, value : Double) -> Double {
  (value - model.location) / model.scale
}

///|
pub fn extreme_support_lower(model : ExtremeValueModel) -> Double {
  match model.law {
    ExtremeGumbel => -1.0e300
    ExtremeFrechet => model.location
    ExtremeWeibull =>
      model.location - model.scale / model.shape.abs().max(1.0e-12)
  }
}

///|
pub fn extreme_support_upper(model : ExtremeValueModel) -> Double {
  match model.law {
    ExtremeGumbel => 1.0e300
    ExtremeFrechet => 1.0e300
    ExtremeWeibull =>
      model.location + model.scale / model.shape.abs().max(1.0e-12)
  }
}

///|
pub fn extreme_cdf(model : ExtremeValueModel, value : Double) -> Double {
  let z = extreme_standardize(model, value)
  match model.law {
    ExtremeGumbel => @math.exp(-@math.exp(-z))
    ExtremeFrechet =>
      if value <= model.location {
        0.0
      } else {
        @math.exp(
          -@math.pow(
            value - model.location,
            -model.shape.max(1.0e-12) / model.scale,
          ),
        )
      }
    ExtremeWeibull => {
      let inner = 1.0 - model.shape * z
      if inner <= 0.0 {
        if model.shape > 0.0 {
          1.0
        } else {
          0.0
        }
      } else {
        @math.exp(-@math.pow(inner, 1.0 / model.shape.abs().max(1.0e-12)))
      }
    }
  }
}

///|
pub fn extreme_survival(model : ExtremeValueModel, value : Double) -> Double {
  (1.0 - extreme_cdf(model, value)).max(0.0).min(1.0)
}

///|
pub fn extreme_pdf(model : ExtremeValueModel, value : Double) -> Double {
  let cdf = extreme_cdf(model, value)
  let survival = extreme_survival(model, value)
  match model.law {
    ExtremeGumbel => cdf * survival / model.scale
    ExtremeFrechet =>
      if value <= model.location {
        0.0
      } else {
        model.shape.max(1.0e-12) /
        model.scale *
        @math.pow((value - model.location) / model.scale, -model.shape - 1.0) *
        survival
      }
    ExtremeWeibull =>
      if cdf == 0.0 || survival == 0.0 {
        0.0
      } else {
        cdf * survival / model.scale
      }
  }
}

///|
pub fn extreme_hazard(model : ExtremeValueModel, value : Double) -> Double {
  let survival = extreme_survival(model, value)
  if survival <= 1.0e-300 {
    1.0e300
  } else {
    extreme_pdf(model, value) / survival
  }
}

///|
pub fn extreme_value_quantile(
  model : ExtremeValueModel,
  probability : Double,
) -> Double {
  if probability <= 0.0 {
    extreme_support_lower(model)
  } else if probability >= 1.0 {
    extreme_support_upper(model)
  } else {
    match model.law {
      ExtremeGumbel =>
        model.location - model.scale * @math.ln(-@math.ln(probability))
      ExtremeFrechet =>
        model.location +
        model.scale /
        @math.pow(-@math.ln(probability), 1.0 / model.shape.max(1.0e-12))
      ExtremeWeibull =>
        model.location +
        model.scale *
        (
          1.0 -
          @math.pow(-@math.ln(probability), model.shape.abs().max(1.0e-12))
        ) /
        model.shape.abs().max(1.0e-12)
    }
  }
}

///|
pub fn extreme_return_level(
  model : ExtremeValueModel,
  return_period : Double,
) -> Double {
  if return_period <= 1.0 {
    abort("return period must exceed one")
  }
  extreme_value_quantile(model, 1.0 - 1.0 / return_period)
}

///|
pub fn extreme_return_probability(
  model : ExtremeValueModel,
  level : Double,
) -> Double {
  extreme_survival(model, level)
}

///|
pub fn extreme_expected_exceedances(
  model : ExtremeValueModel,
  level : Double,
  blocks : Int,
) -> Double {
  if blocks < 0 {
    abort("blocks must be non-negative")
  }
  blocks.to_double() * extreme_survival(model, level)
}

///|
pub fn extreme_exceedance_rate(
  model : ExtremeValueModel,
  level : Double,
) -> Double {
  extreme_survival(model, level)
}

///|
pub fn extreme_tail_mean(model : ExtremeValueModel, level : Double) -> Double {
  let start = level
  let stop = extreme_value_quantile(model, 0.999999)
  if stop <= start {
    start
  } else {
    let steps = 300
    let step = (stop - start) / steps.to_double()
    let mut area = 0.0
    for i in 0..<steps {
      let left = start + i.to_double() * step
      let right = left + step
      area += (extreme_survival(model, left) + extreme_survival(model, right)) *
        step /
        2.0
    }
    if extreme_survival(model, level) == 0.0 {
      level
    } else {
      level + area / extreme_survival(model, level)
    }
  }
}

///|
pub fn extreme_mean_excess(model : ExtremeValueModel, level : Double) -> Double {
  extreme_tail_mean(model, level) - level
}

///|
pub fn extreme_risk_ratio(
  model : ExtremeValueModel,
  first_level : Double,
  second_level : Double,
) -> Double {
  extreme_survival(model, first_level) /
  extreme_survival(model, second_level).max(1.0e-300)
}

///|
pub fn extreme_quantile_curve(
  model : ExtremeValueModel,
  probabilities : Array[Double],
) -> Array[Double] {
  probabilities.map(probability => extreme_value_quantile(model, probability))
}

///|
pub fn extreme_survival_curve(
  model : ExtremeValueModel,
  levels : Array[Double],
) -> Array[Double] {
  levels.map(level => extreme_survival(model, level))
}

///|
pub fn extreme_hazard_curve(
  model : ExtremeValueModel,
  levels : Array[Double],
) -> Array[Double] {
  levels.map(level => extreme_hazard(model, level))
}

///|
pub struct ExtremeBlock {
  block_id : Int
  maximum : Double
  minimum : Double
  mean : Double
  count : Int
}

///|
pub fn extreme_block(block_id : Int, values : Array[Double]) -> ExtremeBlock {
  if block_id < 0 || values.is_empty() {
    abort("invalid extreme block")
  }
  {
    block_id,
    maximum: max_value(values),
    minimum: min_value(values),
    mean: mean(values),
    count: values.length(),
  }
}

///|
pub fn extreme_block_range(block : ExtremeBlock) -> Double {
  block.maximum - block.minimum
}

///|
pub fn extreme_block_excess(block : ExtremeBlock, threshold : Double) -> Double {
  (block.maximum - threshold).max(0.0)
}

///|
pub fn extreme_block_is_exceedance(
  block : ExtremeBlock,
  threshold : Double,
) -> Bool {
  block.maximum > threshold
}

///|
pub fn extreme_block_score(block : ExtremeBlock, threshold : Double) -> Double {
  extreme_block_excess(block, threshold) / (block.mean.abs() + 1.0)
}

///|
pub fn extreme_blocks_maxima(blocks : Array[ExtremeBlock]) -> Array[Double] {
  blocks.map(block => block.maximum)
}

///|
pub fn extreme_blocks_minima(blocks : Array[ExtremeBlock]) -> Array[Double] {
  blocks.map(block => block.minimum)
}

///|
pub fn extreme_blocks_means(blocks : Array[ExtremeBlock]) -> Array[Double] {
  blocks.map(block => block.mean)
}

///|
pub fn extreme_blocks_exceedance_count(
  blocks : Array[ExtremeBlock],
  threshold : Double,
) -> Int {
  blocks.fold(init=0, (count, block) => {
    if block.maximum > threshold {
      count + 1
    } else {
      count
    }
  })
}

///|
pub fn extreme_blocks_exceedance_fraction(
  blocks : Array[ExtremeBlock],
  threshold : Double,
) -> Double {
  if blocks.is_empty() {
    0.0
  } else {
    extreme_blocks_exceedance_count(blocks, threshold).to_double() /
    blocks.length().to_double()
  }
}

///|
pub fn extreme_blocks_mean_excess(
  blocks : Array[ExtremeBlock],
  threshold : Double,
) -> Double {
  let exceedances = blocks.filter(block => block.maximum > threshold)
  if exceedances.is_empty() {
    0.0
  } else {
    mean(exceedances.map(block => extreme_block_excess(block, threshold)))
  }
}

///|
pub fn extreme_blocks_rank(blocks : Array[ExtremeBlock]) -> Array[ExtremeBlock] {
  let result = blocks.copy()
  result.sort_by((left, right) => {
    if left.maximum > right.maximum {
      -1
    } else if left.maximum < right.maximum {
      1
    } else {
      0
    }
  })
  result
}

///|
pub struct GeneralizedParetoFit {
  threshold : Double
  scale : Double
  shape : Double
  exceedance_count : Int
  total_count : Int
  log_likelihood : Double
  tail_fraction : Double
}

///|
pub fn generalized_pareto_fit(
  values : Array[Double],
  threshold : Double,
) -> GeneralizedParetoFit {
  let excesses = values
    .filter(value => value > threshold)
    .map(value => value - threshold)
  if excesses.is_empty() {
    abort("GPD fit requires exceedances")
  }
  let average = mean(excesses)
  let spread = variance(excesses, unbiased=false)
  let shape = if spread <= average * average {
    0.0
  } else {
    0.5 * (1.0 - average * average / spread)
  }
  let scale = average * (1.0 - shape).max(0.1)
  let likelihood = excesses.fold(init=0.0, (total, excess) => {
    total +
    @math.ln(generalized_pareto_density(excess, scale, shape).max(1.0e-300))
  })
  {
    threshold,
    scale,
    shape,
    exceedance_count: excesses.length(),
    total_count: values.length(),
    log_likelihood: likelihood,
    tail_fraction: excesses.length().to_double() / values.length().to_double(),
  }
}

///|
pub fn generalized_pareto_density(
  excess : Double,
  scale : Double,
  shape : Double,
) -> Double {
  if excess < 0.0 || scale <= 0.0 {
    0.0
  } else if shape.abs() < 1.0e-12 {
    @math.exp(-excess / scale) / scale
  } else {
    let inner = 1.0 + shape * excess / scale
    if inner <= 0.0 {
      0.0
    } else {
      @math.pow(inner, -1.0 / shape - 1.0) / scale
    }
  }
}

///|
pub fn generalized_pareto_cdf(
  excess : Double,
  scale : Double,
  shape : Double,
) -> Double {
  if excess <= 0.0 {
    0.0
  } else if shape.abs() < 1.0e-12 {
    1.0 - @math.exp(-excess / scale)
  } else {
    let inner = 1.0 + shape * excess / scale
    if inner <= 0.0 {
      1.0
    } else {
      1.0 - @math.pow(inner, -1.0 / shape)
    }
  }
}

///|
pub fn generalized_pareto_survival(
  excess : Double,
  scale : Double,
  shape : Double,
) -> Double {
  1.0 - generalized_pareto_cdf(excess, scale, shape)
}

///|
pub fn generalized_pareto_quantile(
  probability : Double,
  scale : Double,
  shape : Double,
) -> Double {
  if probability <= 0.0 {
    0.0
  } else if probability >= 1.0 {
    1.0e300
  } else if shape.abs() < 1.0e-12 {
    -scale * @math.ln(1.0 - probability)
  } else {
    scale / shape * (@math.pow(1.0 - probability, -shape) - 1.0)
  }
}

///|
pub fn generalized_pareto_return_level(
  fit : GeneralizedParetoFit,
  return_period : Double,
) -> Double {
  if return_period <= 1.0 {
    abort("return period must exceed one")
  }
  let probability = 1.0 -
    1.0 / (return_period * fit.tail_fraction).max(1.0 + 1.0e-12)
  fit.threshold + generalized_pareto_quantile(probability, fit.scale, fit.shape)
}

///|
pub fn generalized_pareto_tail_mean(fit : GeneralizedParetoFit) -> Double {
  if fit.shape >= 1.0 {
    1.0e300
  } else {
    fit.threshold +
    (fit.scale + fit.shape * fit.threshold) / (1.0 - fit.shape).max(1.0e-12)
  }
}

///|
pub fn generalized_pareto_probability_above(
  fit : GeneralizedParetoFit,
  level : Double,
) -> Double {
  if level <= fit.threshold {
    fit.tail_fraction
  } else {
    fit.tail_fraction *
    generalized_pareto_survival(level - fit.threshold, fit.scale, fit.shape)
  }
}

///|
pub fn generalized_pareto_exceedance_rate(
  fit : GeneralizedParetoFit,
  exposure : Double,
) -> Double {
  if exposure < 0.0 {
    abort("exposure must be non-negative")
  }
  fit.tail_fraction * exposure
}

///|
pub fn generalized_pareto_checksum(fit : GeneralizedParetoFit) -> Double {
  fit.threshold +
  fit.scale +
  fit.shape +
  fit.exceedance_count.to_double() +
  fit.total_count.to_double() +
  fit.log_likelihood +
  fit.tail_fraction
}

///|
pub fn extreme_fit_gumbel(values : Array[Double]) -> ExtremeValueModel {
  if values.is_empty() {
    abort("extreme fit requires values")
  }
  let location = mean(values)
  let scale = variance(values, unbiased=false).sqrt() * (6.0.sqrt() / @math.PI)
  extreme_value_model(
    ExtremeGumbel,
    location,
    scale.max(1.0e-12),
    0.0,
    min_value(values),
    "gumbel-fit",
  )
}

///|
pub fn extreme_fit_frechet(values : Array[Double]) -> ExtremeValueModel {
  if values.is_empty() {
    abort("extreme fit requires values")
  }
  let location = min_value(values)
  let shifted = values.map(value => value - location + 1.0e-12)
  let mean_shifted = mean(shifted)
  let shape = (mean_shifted *
  mean_shifted /
  variance(shifted, unbiased=false).max(1.0e-12) +
  1.0).max(1.1)
  extreme_value_model(
    ExtremeFrechet,
    location,
    mean_shifted,
    shape,
    location,
    "frechet-fit",
  )
}

///|
pub fn extreme_fit_weibull(values : Array[Double]) -> ExtremeValueModel {
  if values.is_empty() {
    abort("extreme fit requires values")
  }
  let location = mean(values)
  let scale = variance(values, unbiased=false).sqrt().max(1.0e-12)
  extreme_value_model(
    ExtremeWeibull,
    location,
    scale,
    1.0,
    min_value(values),
    "weibull-extreme-fit",
  )
}

///|
pub fn extreme_fit_best(values : Array[Double]) -> ExtremeValueModel {
  let candidates = [
    extreme_fit_gumbel(values),
    extreme_fit_frechet(values),
    extreme_fit_weibull(values),
  ]
  let mut best = candidates[0]
  let mut best_error = extreme_fit_error(best, values)
  for candidate in candidates[1:] {
    let error = extreme_fit_error(candidate, values)
    if error < best_error {
      best = candidate
      best_error = error
    }
  }
  best
}

///|
pub fn extreme_fit_error(
  model : ExtremeValueModel,
  values : Array[Double],
) -> Double {
  if values.is_empty() {
    0.0
  } else {
    let ordered = values.copy()
    ordered.sort()
    let mut total = 0.0
    for i in 0..<ordered.length() {
      let empirical = (i + 1).to_double() / (ordered.length() + 1).to_double()
      total += (extreme_cdf(model, ordered[i]) - empirical) *
        (extreme_cdf(model, ordered[i]) - empirical)
    }
    (total / ordered.length().to_double()).sqrt()
  }
}

///|
pub fn extreme_model_score(
  model : ExtremeValueModel,
  values : Array[Double],
) -> Double {
  @math.exp(-extreme_fit_error(model, values))
}

///|
pub fn extreme_model_checksum(model : ExtremeValueModel) -> Double {
  model.location + model.scale + model.shape + model.threshold
}

///|
pub fn extreme_risk_budget(
  model : ExtremeValueModel,
  level : Double,
  budget : Double,
) -> Bool {
  if budget < 0.0 {
    abort("risk budget must be non-negative")
  }
  extreme_survival(model, level) <= budget
}

///|
pub fn extreme_design_level(
  model : ExtremeValueModel,
  budget : Double,
) -> Double {
  if budget <= 0.0 || budget >= 1.0 {
    abort("budget probability must be in (0, 1)")
  }
  extreme_value_quantile(model, 1.0 - budget)
}

///|
pub fn extreme_expected_loss(
  model : ExtremeValueModel,
  threshold : Double,
  exposure : Double,
  loss : Double,
) -> Double {
  if exposure < 0.0 || loss < 0.0 {
    abort("invalid extreme loss inputs")
  }
  exposure * extreme_survival(model, threshold) * loss
}

///|
pub fn extreme_expected_loss_curve(
  model : ExtremeValueModel,
  levels : Array[Double],
  exposure : Double,
  loss : Double,
) -> Array[Double] {
  levels.map(level => extreme_expected_loss(model, level, exposure, loss))
}

///|
pub fn extreme_curve_checksum(values : Array[Double]) -> Double {
  values.fold(init=0.0, (total, value) => total + value)
}
