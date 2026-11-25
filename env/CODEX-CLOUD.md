# Codex Cloud 环境配置

环境名为 `automatic-waffle-research`。仓库为 `lafzhang/automatic-waffle`，默认分支为 `main`。环境访问选择 `Only me`，首轮配置无需 HTTP 密钥、VPN、预览端口或出站身份。

## Install script

```bash
set -euo pipefail
test -f scripts/setup.sh
bash scripts/setup.sh all
bash scripts/check.sh all
```

安装脚本从仓库根目录运行。初建环境时，核对会话实际执行的命令、四个层的退出状态和安装日志。工作台是批处理环境，Start skill 可以留空。

依赖安装需要 PyPI、GitHub 发布件和实际跳转域名、系统 APT 源、`cdn.posit.co`、`packagemanager.posit.co`、`bioconductor.org` 及其实际下载镜像、`downloads.imagej.net`。按日志补充具体域名。工作流验收使用合成数据。需要访问真实数据的任务按各自来源单独配置。

## 发布后复验

从环境选择器发起一个新任务，核对下列命令的输出，然后在建设文档记录任务链接与日志。

```bash
git rev-parse HEAD
bash scripts/check.sh all
```

`check.sh` 的四个层都应返回成功。查看输出中的 `versions.txt`、`versions.csv`、`experiment.rds`、`fiji.log` 和 `stats.csv`。新任务运行的 Git SHA 应包含预期的工作台文件。可选 TCGAbiolinks 只在需要时安装，单独记录结果。

改动依赖或工具版本后，重新运行安装与验收，发布更新并新建任务核查。已有任务保持独立的工作状态。环境设置位于 [Codex Cloud 环境](https://learn.chatgpt.com/docs/environments/cloud-environments) 所述的设置入口。
