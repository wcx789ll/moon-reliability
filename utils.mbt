///|
/// Standard normal cumulative distribution function (CDF)
/// $\Phi(x) = \frac{1}{2} \left[ 1 + \text{erf}\left( \frac{x}{\sqrt{2}} \right) \right]$
pub fn standard_normal_cdf(x : Double) -> Double {
  0.5 * (1.0 + erf(x / 1.4142135623730951))
}

///|
/// Error function approximation (Abramowitz and Stegun)
/// Maximum error: $1.5 \times 10^{-7}$
pub fn erf(x : Double) -> Double {
  let p = 0.3275911
  let a1 = 0.254829592
  let a2 = -0.284496736
  let a3 = 1.421413741
  let a4 = -1.453152027
  let a5 = 1.061405429

  let sign = if x < 0.0 { -1.0 } else { 1.0 }
  let abs_x = x.abs()

  let t = 1.0 / (1.0 + p * abs_x)
  let y = 1.0 -
    ((((a5 * t + a4) * t + a3) * t + a2) * t + a1) *
    t *
    @math.exp(-abs_x * abs_x)

  sign * y
}

///|
/// Inverse error function approximation
pub fn erfinv(y : Double) -> Double {
  let a = 0.147
  let sign = if y < 0.0 { -1.0 } else { 1.0 }
  let y2 = y * y

  let ln1_y2 = @math.ln(1.0 - y2)
  let term1 = 2.0 / (@math.PI * a) + ln1_y2 / 2.0

  sign * ((term1 * term1 - ln1_y2 / a).sqrt() - term1).sqrt()
}

///|
/// Inverse standard normal CDF (Probit function)
pub fn standard_normal_inv(p : Double) -> Double {
  1.4142135623730951 * erfinv(2.0 * p - 1.0)
}

///|
/// Gamma function approximation using Lanczos approximation
pub fn gamma(z : Double) -> Double {
  if z < 0.5 {
    @math.PI / (@math.sin(@math.PI * z) * gamma(1.0 - z))
  } else {
    let z = z - 1.0
    let p = [
      676.5203681218851, -1259.1392167224028, 771.32342877765313, -176.61502916214059,
      12.507343278686905, -0.13857109526572012, 9.9843695780195716e-6, 1.5056327351493116e-7,
    ]

    let mut x = 0.9999999927443152
    for i in 0..<p.length() {
      x = x + p[i] / (z + i.to_double() + 1.0)
    }
    let t = z + p.length().to_double() - 0.5
    (2.0 * @math.PI).sqrt() * @math.pow(t, z + 0.5) * @math.exp(-t) * x
  }
}
