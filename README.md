# automatic-waffle 科研云端工作台

仓库提供 Python 科学计算、R 统计、Bioconductor 组学分析以及 ImageJ/Fiji 无界面批处理。版本见 [env/versions.env](env/versions.env)，Codex Cloud 的安装和复验见 [env/CODEX-CLOUD.md](env/CODEX-CLOUD.md)。

## 安装和验证

安装入口面向 Linux x86-64，需要 Bash、curl、tar 和 flock。有 APT 安装权限时，脚本可在 Ubuntu 22.04、24.04、26.04 和 Debian 13 上使用 Posit 的 R 4.6.1。普通用户可使用已有的 R 4.6.1，或由脚本用 micromamba 将 R 和编译工具安装到工作台用户缓存。Fiji 需要 unzip 和 python3。

```bash
bash scripts/setup.sh all
bash scripts/check.sh all
```

| 层 | 单独安装和验证 | 验收数据 |
| --- | --- | --- |
| Python | `bash scripts/setup.sh python` 和 `bash scripts/check.sh python` | 组均值、斜率、Excel 回读、PNG 尺寸和 TIFF 像素 |
| R | `bash scripts/setup.sh r` 和 `bash scripts/check.sh r` | 组均值、回归系数、JSON 回读和 PNG 输出 |
| Bioconductor | `bash scripts/setup.sh bioc` 和 `bash scripts/check.sh bioc` | 样本注释对齐、SummarizedExperiment 对象和 limma 估计 |
| Fiji | `bash scripts/setup.sh fiji` 和 `bash scripts/check.sh fiji` | 实际运行 IJM 宏，检查 12 个像素的统计值和 TIFF 文件 |
| TCGA 可选 | `bash scripts/setup.sh tcga` 和 `bash scripts/check.sh tcga` | TCGAbiolinks 导出接口和 Bioconductor 基线。运行时只用合成数据 |

`check.sh` 将每次测试写到 `outputs/smoke/` 下的独立目录。它会打印路径和 Git SHA。失败时返回非零退出码。可以通过第二个参数给出其他输出父目录。

R 使用固定日期的 CRAN 来源与 Bioconductor 3.23 发行线。Python 校验清单中每个安装包的版本，Fiji 下载固定归档并校验其发布方 SHA-256。主要包和运行时版本写入验收目录。

使用用户目录中的 R 时，可从仓库根目录运行 `source scripts/runtime.sh`，然后用 `run_rscript` 执行 R 脚本。`WORKBENCH_RSCRIPT` 可指定已有的 R 4.6.1。系统 R 与用户安装的 R 默认各用自己的包库。

## 目录用途

| 路径 | 内容 |
| --- | --- |
| `env/` | Python 版本清单、R 安装脚本与 Cloud 配置 |
| `scripts/` | 独立安装入口和自动验收 |
| `examples/fixtures/` | 小型合成输入 |
| `data/` 与 `outputs/` | 本地或任务工作目录中的数据和结果，均由 Git 忽略 |

原始显微图像、GDC 大文件、凭证和受限数据应通过其已获授权的位置使用。项目专用的 Fiji 更新站点和需窗口或快捷键的宏，应先在 Fiji 桌面验证。

## 从已有 Windows 工具验证

在已装清单对应的 Python、R 或 Fiji 时，可直接运行对应样例。下面的 Fiji 启动文件使用示例名，按实际安装路径替换。

```powershell
python scripts/checks/python_smoke.py outputs/smoke/windows-python
$config = Get-Content env/versions.env -Raw | ConvertFrom-StringData
$env:R_VERSION = $config.R_VERSION
$env:BIOC_VERSION = $config.BIOC_VERSION
Rscript --vanilla scripts/checks/r_smoke.R r examples/fixtures/measurements.csv outputs/smoke/windows-r
Rscript --vanilla scripts/checks/r_smoke.R bioc examples/fixtures/measurements.csv outputs/smoke/windows-bioc

$fijiOutput = New-Item -ItemType Directory -Path 'outputs/smoke/windows-fiji' -Force
& 'C:\path\to\Fiji\fiji-windows-x64.exe' --headless -macro scripts/checks/fiji_smoke.ijm $fijiOutput.FullName
python scripts/checks/fiji_output.py $fijiOutput.FullName
```
