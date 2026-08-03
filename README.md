# moon-reliability

MoonBit 可靠性与寿命数据分析库 (MoonBit Reliability and Lifetime Data Analysis Library)

## 申报书概览 (Hackathon Proposal Summary)

- **项目名称 / Project Name:** moon-reliability
- **GitHub 仓库 / Repository:** https://github.com/wcx789ll/moon-reliability
- **项目方向 / Direction:** 生态库开发 (基础科学计算与统计工具)
- **目标场景 / Target Scenario:** 工业界硬件设备的寿命预测、SaaS系统的可用性建模、加速寿命试验 (Accelerated Life Testing) 的基础数据支持库。
- **核心功能 / Core Features:**
  - 支持常用寿命分布：Weibull（威布尔分布）、Lognormal（对数正态分布）、Exponential（指数分布）。
  - 提供可靠度 (Reliability)、失效概率 (Probability of Failure)、故障率/失效率 (Hazard Rate) 的计算。
  - 支持计算平均故障间隔时间 (MTBF) 及特定置信水平的分位数寿命 (Quantile Life)。
  - 内置 Gamma 函数、误差函数 (Error function) 和逆标准正态分布等底层数学工具，为未来扩展复杂的可靠性模型提供支撑。
- **实施计划 / Implementation Plan:** 
  - 本库已实现三大基础寿命分布。后续将扩展删失数据 (Censored data) 支持和极大似然估计 (MLE) 拟合功能。
- **原创声明 / Originality Statement:** 这是一个完全原创的开源项目，没有直接移植其他特定库，而是根据可靠性工程标准算法 (如 Abramowitz and Stegun 近似，Lanczos 近似等) 在 MoonBit 中从零实现。

## 快速使用 (Quick Start)

### 引入依赖

在你的 `moon.mod` 中添加依赖：

```json
import {
  "wcx789ll/moon-reliability"
}
```

### Weibull 分布示例

Weibull 分布是可靠性工程中最常用的分布之一，能够模拟早期失效（形状参数 k < 1）、偶然失效（k = 1）和耗损失效（k > 1）。

```mbt check
test {
  let weibull = @moon_reliability.Weibull::new(100.0, 2.0)
  
  // 计算 50 小时时的可靠度
  let r50 = weibull.reliability(50.0)
  
  // 计算 MTBF
  let mtbf = weibull.mtbf()
  
  inspect!(r50 > 0.778 && r50 < 0.779, content="true")
}
```

### Lognormal 分布示例

对数正态分布常用于疲劳失效或存在大量微小损伤累积的过程。

```mbt check
test {
  let lognormal = @moon_reliability.Lognormal::new(5.0, 0.5)
  
  // 计算 100 小时时的累积失效概率
  let f100 = lognormal.cdf(100.0)
  
  // 计算分位数：90% 产品能够达到的寿命 (B10寿命)
  let b10 = lognormal.quantile(0.1)
  
  inspect!(f100 > 0.1, content="true")
}
```

### 指数分布示例

指数分布代表失效率恒定的偶然失效期。

```mbt check
test {
  let exp = @moon_reliability.Exponential::new(0.01) // 故障率为 0.01
  
  let mtbf = exp.mtbf()
  inspect!(mtbf, content="100.0")
  
  let r50 = exp.reliability(50.0)
  inspect!(r50 > 0.606, content="true")
}
```

## 许可证 (License)

Apache-2.0
