///|
test "Lognormal::reliability" {
  let dist = Lognormal::new(0.0, 1.0)
  // R(1) = 1 - Phi((ln(1)-0)/1) = 1 - Phi(0) = 0.5
  let r = dist.reliability(1.0)
  inspect(r > 0.499 && r < 0.501, content="true")
}

///|
test "Lognormal::mtbf" {
  let dist = Lognormal::new(1.0, 0.5)
  // MTBF = exp(1.0 + 0.5^2 / 2) = exp(1.125) = 3.0802
  let m = dist.mtbf()
  inspect(m > 3.08 && m < 3.09, content="true")
}

///|
test "Lognormal::quantile" {
  let dist = Lognormal::new(0.0, 1.0)
  // q(0.5) = exp(0 + 1 * z(0.5)) = exp(0) = 1.0
  let q = dist.quantile(0.5)
  inspect(q > 0.99 && q < 1.01, content="true")
}
