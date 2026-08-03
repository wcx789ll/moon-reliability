///|
test "Weibull::reliability" {
  let w = Weibull::new(100.0, 2.0)
  // R(100) = e^(-(100/100)^2) = e^-1 ≈ 0.3678794
  let r = w.reliability(100.0)
  inspect(r > 0.3678 && r < 0.3679, content="true")
}

///|
test "Weibull::mtbf" {
  let w = Weibull::new(100.0, 1.0) // When shape=1, Weibull is Exponential with lambda=1/100
  let m = w.mtbf()
  // gamma(2) = 1, so mtbf = 100 * 1 = 100
  inspect(m > 99.9 && m < 100.1, content="true")
}

///|
test "Weibull::quantile" {
  let w = Weibull::new(50.0, 2.0)
  let q = w.quantile(0.6321205588) // 1 - e^-1
  inspect(q > 49.9 && q < 50.1, content="true")
}
