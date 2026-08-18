///|
/// Arrhenius accelerated-life model: log life = intercept + slope / T.
pub struct AcceleratedLifeModel {
  law : String
  coefficients : Array[Double]
  reference_stress : Double
  unit : String
  fit : RegressionResult
}

///|
pub fn accelerated_life_model(
  law~ : String,
  coefficients~ : Array[Double],
  reference_stress~ : Double,
  unit~ : String,
  fit~ : RegressionResult,
) -> AcceleratedLifeModel {
  { law, coefficients, reference_stress, unit, fit }
}

///|
pub fn fit_arrhenius(
  temperature : Array[Double],
  life : Array[Double],
  reference : Double,
) -> AcceleratedLifeModel {
  if temperature.length() != life.length() || temperature.length() < 3 {
    abort("Arrhenius fit requires paired data")
  }
  let reciprocal = temperature.map(value => 1.0 / value)
  let log_life = life.map(value => @math.ln(value))
  let fit = linear_regression(reciprocal, log_life)
  accelerated_life_model(
    law="arrhenius",
    coefficients=fit.coefficients.copy(),
    reference_stress=reference,
    unit="temperature",
    fit~,
  )
}

///|
pub fn fit_inverse_power(
  stress : Array[Double],
  life : Array[Double],
  reference : Double,
) -> AcceleratedLifeModel {
  if stress.length() != life.length() || stress.length() < 3 {
    abort("inverse-power fit requires paired data")
  }
  let log_stress = stress.map(value => @math.ln(value))
  let log_life = life.map(value => @math.ln(value))
  let fit = linear_regression(log_stress, log_life)
  accelerated_life_model(
    law="inverse-power",
    coefficients=fit.coefficients.copy(),
    reference_stress=reference,
    unit="stress",
    fit~,
  )
}

///|
pub fn fit_eyring(
  temperature : Array[Double],
  stress : Array[Double],
  life : Array[Double],
  reference : Double,
) -> AcceleratedLifeModel {
  if temperature.length() != stress.length() ||
    temperature.length() != life.length() ||
    temperature.length() < 3 {
    abort("Eyring fit requires three aligned arrays")
  }
  let features = Array::makei(temperature.length(), i => {
    let reciprocal = 1.0 / temperature[i]
    let log_stress = @math.ln(stress[i])
    reciprocal + 0.01 * log_stress
  })
  let fit = linear_regression(features, life.map(value => @math.ln(value)))
  accelerated_life_model(
    law="eyring",
    coefficients=fit.coefficients.copy(),
    reference_stress=reference,
    unit="combined",
    fit~,
  )
}

///|
pub fn AcceleratedLifeModel::predict_log_life(
  self : AcceleratedLifeModel,
  stress : Double,
) -> Double {
  if self.law is "arrhenius" {
    self.coefficients[0] + self.coefficients[1] / stress
  } else {
    self.coefficients[0] + self.coefficients[1] * @math.ln(stress)
  }
}

///|
pub fn AcceleratedLifeModel::predict_life(
  self : AcceleratedLifeModel,
  stress : Double,
) -> Double {
  @math.exp(self.predict_log_life(stress))
}

///|
pub fn AcceleratedLifeModel::acceleration_factor(
  self : AcceleratedLifeModel,
  use_stress : Double,
) -> Double {
  self.predict_life(self.reference_stress) / self.predict_life(use_stress)
}

///|
pub fn AcceleratedLifeModel::confidence_band(
  self : AcceleratedLifeModel,
  stress : Double,
  confidence_level : Double,
) -> MetricEstimate {
  let prediction = self.predict_life(stress)
  let error = residual_standard_error(self.fit)
  let z = standard_normal_inv(0.5 + confidence_level / 2.0)
  metric_estimate(
    estimate=prediction,
    lower=@math.exp(self.predict_log_life(stress) - z * error),
    upper=@math.exp(self.predict_log_life(stress) + z * error),
    confidence_level~,
  )
}

///|
pub fn arrhenius_acceleration(
  activation_energy : Double,
  use_temperature : Double,
  reference_temperature : Double,
) -> Double {
  let boltzmann = 8.617333262e-5
  @math.exp(
    activation_energy /
    boltzmann *
    (1.0 / use_temperature - 1.0 / reference_temperature),
  )
}

///|
pub fn inverse_power_acceleration(
  exponent : Double,
  use_stress : Double,
  reference_stress : Double,
) -> Double {
  @math.pow(use_stress / reference_stress, exponent)
}

///|
pub fn thermal_stress_grid(
  start : Double,
  stop : Double,
  count : Int,
) -> Array[Double] {
  linspace(start, stop, count)
}
