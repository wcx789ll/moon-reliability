# moon-reliability

MoonBit 可靠性工程与寿命数据分析库，面向硬件寿命试验、SaaS 可用性分析、质量控制和维护策略评估。库内算法使用 MoonBit 从零实现，包含可复现的本地基准和边界测试。

## 能力概览

- 寿命分布：Exponential、Weibull、Lognormal、Normal、Gamma、Gompertz、Log-logistic、Pareto、Inverse Gaussian，以及浴盆型组合模型。
- 可靠性指标：PDF、CDF、可靠度、失效率、累积风险、MTTF/MTBF、分位数寿命和条件剩余寿命。
- 生存数据：右删失、左删失、区间删失、Kaplan–Meier、Nelson–Aalen、生命表和竞争风险。
- 参数估计：指数、Weibull、Lognormal 的删失数据 MLE，观测权重、置信区间、AIC/BIC 和模型诊断。
- 工程分析：Arrhenius、逆幂律、Eyring 加速模型，串并联系统、网络可靠性、马尔可夫状态、保修、预防性维护、SLA 和安全分析。
- 数据与决策：Bootstrap/Jackknife/Delta 不确定性、随机模拟、FMEA、故障树、控制图、敏感性分析、试验设计和可靠性增长。

## 快速开始

在 `moon.mod.json` 或依赖配置中加入：

```mbt
import {
  "wcx789ll/moon-reliability" @reliability,
}
```

计算 Weibull 可靠度和 B10 寿命：

```mbt
let model = @reliability.Weibull::new(100.0, 2.0)
let r50 = model.reliability(50.0)
let b10 = model.quantile(0.1)
```

使用删失样本进行 Kaplan–Meier 和 Weibull 拟合：

```mbt
let records = [
  @reliability.LifetimeRecord::observed(12.0),
  @reliability.LifetimeRecord::observed(19.0),
  @reliability.LifetimeRecord::right_censored(25.0),
]
let curve = @reliability.kaplan_meier(records)
let fit = @reliability.fit_weibull_censored(records)
```

## 基准与复现

基准程序位于 `cmd/benchmark`，使用 2,000 条确定性生成的寿命记录、256 个分布网格点和系统可靠性计算。运行：

```text
moon run --target native cmd/benchmark
```

一次已保存的本机结果见 [BENCHMARK.md](BENCHMARK.md)，其中包括输入规模、校验和、运行环境记录方式及 5 次实测耗时。校验和用于防止只测速度而遗漏计算结果；耗时会随 CPU、操作系统和 MoonBit 工具链变化。

## 本地验证

```text
moon fmt --check
moon check --target all --deny-warn
moon test --target all --deny-warn
moon info
moon run --target native cmd/benchmark
```

CI 在 Linux、macOS、Windows 上执行格式检查、全目标检查、全目标测试、API 信息一致性检查和 native 基准冒烟运行，并显式安装 Node.js 以覆盖 JavaScript 目标。

## 项目结构

| 路径 | 内容 |
| --- | --- |
| `*_distribution.mbt` | 概率分布、可靠度和分位数算法 |
| `*_censored.mbt`、`kaplan_meier.mbt` | 删失数据、生存曲线和参数估计 |
| `system_reliability.mbt`、`network_reliability.mbt` | 系统、网络和任务可靠性 |
| `simulation.mbt`、`bootstrap.mbt`、`uncertainty.mbt` | 仿真和不确定性传播 |
| `observability.mbt` | 运行时指标、事故、告警、预算和健康度 |
| `maintenance.mbt`、`warranty.mbt`、`sla_analysis.mbt` | 运维、保修和服务等级分析 |
| `cmd/benchmark` | 可复现的 native 基准入口 |
| `.github/workflows` | 跨平台 CI 与手动发布工作流 |

## 原创与许可证

本项目为面向 MoonBit 生态的原创实现，使用公开的可靠性工程和数值分析算法，不包含第三方项目源码或测试数据的直接复制。项目以 Apache-2.0 协议发布，详见 [LICENSE](LICENSE)。
