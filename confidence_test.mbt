///|
test "confidence_interval" {
  let ci = confidence_interval(100.0, 5.0, 0.95)
  // z(0.975) â‰?1.95996
  // margin â‰?1.95996 * 5 = 9.7998
  // lower â‰?90.2002, upper â‰?109.7998
  @json.@json.inspect!(ci.lower > 90.1 && ci.lower < 90.3, content="true")
  @json.@json.inspect!(ci.upper > 109.7 && ci.upper < 109.9, content="true")
}

