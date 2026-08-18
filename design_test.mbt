///|
test "experimental design dimensions" {
  let design = full_factorial([[-1.0, 1.0], [0.0, 1.0]])
  inspect(design.length(), content="4")
  let replicated = replicate_design(design, 3)
  inspect(replicated.length(), content="12")
  inspect(code_factor(5.0, 0.0, 10.0), content="0")
}

///|
test "latin hypercube stays in unit cube" {
  let design = latin_hypercube(99, 20, 3)
  inspect(design.length(), content="20")
  inspect(
    design.all(point => {
      point.factors.all(value => value >= -0.000001 && value <= 1.000001)
    }),
    content="true",
  )
}

///|
test "optimization finds quadratic minimum" {
  let result = golden_section_minimize(
    -5.0,
    5.0,
    x => (x - 2.0) * (x - 2.0),
    1.0e-6,
  )
  inspect(result.parameter > 1.99 && result.parameter < 2.01, content="true")
  let grid = grid_minimize([-2.0, 0.0, 2.0, 4.0], x => (x - 2.0) * (x - 2.0))
  inspect(grid.parameter, content="2")
}
