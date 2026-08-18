///|
test "kaplan meier handles ties and censoring" {
  let records = [
    failure(1.0),
    failure(1.0),
    right_censored(2.0),
    failure(3.0),
    right_censored(4.0),
  ]
  let curve = kaplan_meier(records)
  inspect(curve.points().length(), content="4")
  inspect(curve.survival_at(0.5), content="1")
  inspect(
    curve.survival_at(1.0) > 0.59 && curve.survival_at(1.0) < 0.61,
    content="true",
  )
  debug_inspect(curve.median_life(), content="Some(3)")
}

///|
test "nelson aalen is monotone" {
  let curve = nelson_aalen([failure(1.0), failure(2.0), right_censored(3.0)])
  let points = curve.points()
  inspect(
    points[0].cumulative_hazard <= points[1].cumulative_hazard,
    content="true",
  )
  inspect(points[1].survival < 1.0, content="true")
}

///|
test "empirical survival retains support" {
  let empirical = empirical_distribution([
    failure(1.0),
    right_censored(2.0),
    failure(3.0),
  ])
  debug_inspect(empirical.support(), content="[1, 2, 3]")
  inspect(empirical.cdf(0.0), content="0")
  inspect(
    empirical.survival(3.0) > 0.32 && empirical.survival(3.0) < 0.34,
    content="true",
  )
}

///|
test "life table exposure and event counts" {
  let table = actuarial_life_table(
    [failure(1.0), failure(2.0), right_censored(4.0)],
    [0.0, 2.0, 4.0],
  )
  inspect(table.intervals().length(), content="2")
  inspect(table.total_failures, content="2")
  debug_inspect(
    interval_event_counts([failure(1.0), failure(3.0)], [0.0, 2.0, 4.0]),
    content="[1, 1]",
  )
}

///|
test "competing risks incidence sums" {
  let records = [
    failure(1.0).with_metadata(cause=1, weight=1.0),
    failure(2.0).with_metadata(cause=2, weight=1.0),
    right_censored(3.0),
  ]
  let curve = cumulative_incidence(records, 2)
  inspect(curve.incidence_at(1, 2.0) > 0.3, content="true")
  inspect(curve.incidence_at(2, 2.0) > 0.2, content="true")
}

///|
test "survival confidence interval remains bounded" {
  let point = survival_point(
    time=1.0,
    at_risk=10,
    events=2,
    censored=0,
    survival=0.8,
    standard_error=0.1,
    cumulative_hazard=0.2,
  )
  let interval = survival_confidence_interval(point, 0.95)
  inspect(interval.lower >= 0.0, content="true")
  inspect(interval.upper <= 1.0, content="true")
}
