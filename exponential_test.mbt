///|
test "Exponential::new" {
  let dist = Exponential::new(0.5)
  inspect(dist.lambda, content="0.5")
}

///|
test "Exponential::reliability" {
  let dist = Exponential::new(0.1)
  let r = dist.reliability(10.0)
  // R(10) = e^(-0.1 * 10) = e^-1 ≈ 0.3678794
  inspect(r > 0.3678 && r < 0.3679, content="true")
}

///|
test "Exponential::mtbf" {
  let dist = Exponential::new(0.2)
  inspect(
    dist.mtbf(),
    content=(
      #|5
    ),
  )
}

///|
test "Exponential::quantile" {
  let dist = Exponential::new(1.0)
  // q(0.5) = -ln(0.5)/1 = 0.693147
  let q = dist.quantile(0.5)
  inspect(q > 0.693 && q < 0.694, content="true")
}
