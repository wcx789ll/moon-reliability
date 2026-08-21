///|
/// Minimal end-to-end example for reliability analysis users.
fn main {
  let model = @reliability.Weibull::new(100.0, 2.0)
  let observations : Array[@reliability.LifeObservation] = [
    @reliability.failure(12.0),
    @reliability.failure(19.0),
    @reliability.right_censored(25.0),
  ]
  let curve = @reliability.kaplan_meier(observations)
  println("weibull_reliability_at_50=\{model.reliability(50.0)}")
  println("weibull_b10_life=\{model.quantile(0.1)}")
  println("kaplan_meier_survival_at_20=\{curve.survival_at(20.0)}")
}
