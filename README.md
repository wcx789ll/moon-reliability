# moon-reliability

MoonBit 可靠性工程与寿命数据分析库，面向寿命试验、设备健康评估、服务可用性分析、质量控制和维护决策。

## 项目定位

`moon-reliability` 提供从概率分布和数值计算，到删失生存数据、参数估计、系统可靠性和运行时指标分析的一组 MoonBit 原生 API。项目强调可组合的数据结构、明确的边界行为和可复现的计算结果，适合作为 MoonBit 工程项目中的可靠性分析基础库。

## 核心能力

- **寿命分布**：Exponential、Weibull、Lognormal、Normal、Gamma、Gompertz、Log-logistic、Pareto、Inverse Gaussian 和浴盆型失效率模型。
- **可靠性指标**：PDF、CDF、可靠度、失效率、累积风险、MTTF/MTBF、分位数寿命和条件剩余寿命。
- **生存分析**：右删失、左删失、区间删失、Kaplan–Meier、Nelson–Aalen、生命表和竞争风险。
- **参数估计**：删失数据 MLE、观测权重、置信区间、AIC/BIC、模型比较和残差诊断。
- **工程模型**：Arrhenius、逆幂律、Eyring 加速寿命模型，串并联系统、网络可靠性和马尔可夫状态模型。
- **工程决策**：可靠性分配、试验计划、软件可靠性增长、贝叶斯更新、极值风险和可修复系统分析。
- **运维闭环**：车队健康、退化建模、维修资源、现场服务、保修精算、SLA、可靠性增长和维护策略。
- **风险与质量**：安全论证、风险登记、供应链质量、数据质量、模型治理、控制图和敏感性分析。
- **不确定性与观测**：Bootstrap、Jackknife、Delta 方法、随机模拟、时序窗口、告警预算和健康评分。

## 快速开始

在使用方的 MoonBit 包配置中加入依赖：

```mbt
import {
  "wcx789ll/moon-reliability" @reliability,
}
```

计算 Weibull 可靠度和 B10 寿命：

```mbt
let model = @reliability.Weibull::new(100.0, 2.0)
let reliability_at_50 = model.reliability(50.0)
let b10_life = model.quantile(0.1)
```

对包含删失记录的样本进行非参数和参数分析：

```mbt
let records : Array[@reliability.LifeObservation] = [
  @reliability.failure(12.0),
  @reliability.failure(19.0),
  @reliability.right_censored(25.0),
]
let curve = @reliability.kaplan_meier(records)
let fit = @reliability.weibull_fit_censored(records)
```

## CLI

仓库包含一个用于结果校验和性能回归的 native CLI：

```text
moon run --target native cmd/benchmark
```

该命令使用确定性输入执行分布计算、统计汇总、生存估计和系统可靠性计算，并输出结果校验和。它不是生产服务入口，而是用于本地复现和 CI 冒烟检查的基准程序。

## 架构

项目采用单模块、按领域拆分的结构，公共 API 位于根包：

| 路径 | 职责 |
| --- | --- |
| `*_distribution.mbt`、`weibull.mbt`、`lognormal.mbt` | 概率分布、可靠度和分位数 |
| `reliability_types.mbt`、`kaplan_meier.mbt`、`life_table.mbt` | 观测记录、生存曲线和生命表 |
| `censored_likelihood.mbt`、`model_selection.mbt` | 删失似然、MLE 和模型比较 |
| `system_reliability.mbt`、`network_reliability.mbt`、`markov_chain.mbt` | 系统、网络和状态转移模型 |
| `simulation.mbt`、`bootstrap.mbt`、`uncertainty.mbt` | 仿真、重采样和不确定性传播 |
| `maintenance.mbt`、`warranty.mbt`、`sla_analysis.mbt` | 维护、保修和服务等级分析 |
| `fleet_analysis.mbt`、`degradation_models.mbt`、`repairable_systems.mbt` | 车队、退化和可修复系统 |
| `maintenance_resources.mbt`、`field_service_operations.mbt`、`condition_monitoring.mbt` | 资源调度、现场服务和状态监测 |
| `test_planning.mbt`、`reliability_allocation.mbt`、`bayesian_reliability.mbt` | 试验设计、指标分配和贝叶斯推断 |
| `extreme_value_models.mbt`、`supply_chain_quality.mbt`、`warranty_analytics.mbt` | 极值、供应链和质保精算 |
| `safety_case.mbt`、`risk_register.mbt`、`reliability_governance.mbt` | 安全论证、风险治理和模型发布 |
| `observability.mbt`、`quality_control.mbt`、`reporting.mbt` | 运行时观测、质量控制和结果汇总 |
| `cmd/benchmark` | native 基准 CLI |
| `*_test.mbt` | 单元、边界和集成测试 |
| `pkg.generated.mbti` | 由 `moon info` 生成的公共接口文件，请勿手工编辑 |

## 基准

基准输入包含 2,000 条确定性寿命记录、256 个分布网格点以及系统可靠性计算。运行：

```text
moon run --target native cmd/benchmark
```

结果校验和、工具链信息和本机耗时记录见 [BENCHMARK.md](BENCHMARK.md)。耗时受操作系统、处理器、缓存状态和 MoonBit 工具链影响，校验和用于确认计算结果未发生非预期变化。

## 测试

格式、编译、全目标测试和接口生成物检查：

```text
moon fmt --check
moon check --target all --deny-warn
moon test --target all --deny-warn
moon info
git diff --exit-code
```

当前测试覆盖 72 个跨目标用例，包括分布边界、空数据和单条数据、删失和同一时刻事件、参数估计、系统退化情形、维修与服务 SLA、数据质量、风险治理、随机模拟、告警阈值和端到端工程流程。

## CI

GitHub Actions 在 Linux、macOS 和 Windows 上执行：

- 安装官方 stable MoonBit 工具链并输出版本信息；
- 安装 Node.js，覆盖 JavaScript 目标；
- 执行格式检查、全目标编译和全目标测试；
- 验证 `moon info` 生成的接口文件没有未提交差异；
- 运行 native benchmark smoke test。

工作流位于 `.github/workflows/test.yml`。Mooncakes 发布工作流位于 `.github/workflows/publish.yml`，通过手动触发执行。

## 许可证

本项目采用 [Apache License 2.0](LICENSE)。
