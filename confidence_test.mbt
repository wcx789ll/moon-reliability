///|
test "confidence_interval" {
  let ci = confidence_interval(100.0, 5.0, 0.95)
  // z(0.975) ≈ 1.95996
  // margin ≈ 1.95996 * 5 = 9.7998
  // lower ≈ 90.2002, upper ≈ 109.7998
  inspect(ci.lower > 90.1 && ci.lower < 90.3, content="true")
  inspect(ci.upper > 109.7 && ci.upper < 109.9, content="true")
}
