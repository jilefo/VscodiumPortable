---
AIGC:
    Label: "1"
    ContentProducer: 001191440300708461136T1XGW3
    ProduceID: 57f58889d0fc6fd8c56ed2e8e560347f_638f42e7c85c11f1944f525400248c00
    ReservedCode1: HLr4cIGOUXQzojh44ah/VlJp+lfAxCaDycNpQbUVIXwNLYCM4828gRj20oI9pY4bUC3yyZOV3y3I7IqqBNsr5VMw5JFnPEXBZrPRurgfcuWEVebIVjjLc1kHPnrlrVYsSlotjK9VDcrg+gwo0grPC8pQX+l15CY2pCv1/CEr9rQVtkDe/vMP7Q7IZSs=
    ContentPropagator: 001191440300708461136T1XGW3
    PropagateID: 57f58889d0fc6fd8c56ed2e8e560347f_638f42e7c85c11f1944f525400248c00
    ReservedCode2: HLr4cIGOUXQzojh44ah/VlJp+lfAxCaDycNpQbUVIXwNLYCM4828gRj20oI9pY4bUC3yyZOV3y3I7IqqBNsr5VMw5JFnPEXBZrPRurgfcuWEVebIVjjLc1kHPnrlrVYsSlotjK9VDcrg+gwo0grPC8pQX+l15CY2pCv1/CEr9rQVtkDe/vMP7Q7IZSs=
---

# CURSOR_TASK.md —— VscodiumPortable GitHub 自动发布链路排查与验证

> 用法：在 Cursor 中打开本项目（D:\Projects\VscodiumPortable），对话框输入：
> 「请按 CURSOR_TASK.md 文档执行」
> 本文件与同目录 .github/workflows/* 配合使用。详细背景另见 output 目录的 VscodiumPortable_github_auto_release_task.md（若存在）。

---

你是资深 DevOps 工程师，请接管 VscodiumPortable 项目的 GitHub Actions 自动发布链路排查与验证任务。

## 背景
- 本地项目：D:\Projects\VscodiumPortable（portapps/vscodium-portable 的本地维护副本，不带连字符）
- 远端仓库：https://github.com/jilefo/VscodiumPortable（公开，默认分支 master）
- 参考文档：D:\Projects\VscodiumPortable\CURSOR_TASK.md（本文档）；若需完整背景可读同目录 .github/workflows/*.yml 与 build.properties、versioninfo.json

## 当前状态（已于 2026-10-15 更新）
- workflow 已全部推送：auto-update.yml（schedule 每日 UTC 8:00 + workflow_dispatch）、app-build.yml（本地化副本 draft:false）、build.yml（引用本地 app-build）、zizmor.yml、released.yml、labels.yml
- secret RELEASE_TOKEN 已配置（PAT，需 contents:write + workflows:write），已实测可用
- ✅ P0 已解决：原「Set up job 秒失败」根因是 `actions/github-script` 固定 SHA 写错（仅前 24 位与真实 v7.0.1 一致），已修为 `60a0d83039c74a4aee543508d2ffcb1c3799cdea`（commit df4af9f）
- ✅ P0 已解决：PAT 推送被 checkout 凭据覆盖导致 403，已加 `persist-credentials: false`（commit fb6c358）
- ✅ 全链路已 100% 实证：detect → bump → PAT push commit+tag → tag 触发下游 build → 编译 → 发布 Release。首个正式 Release 已发布：`1.140.06880-60`（draft=false，资产齐全）
- 当前版本：app.version=1.140.06880、app.release=60（与上游一致，auto-update 为 no-op）
- 遗留 P1：released.yml（VirusTotal）需配置 VT_API_KEY / VT_MONITOR_API_KEY 才能真实验证，不影响发版主链路；dependabot 已自动开 4 个 actions 版本升级 PR（含 checkout v7.0.1，可消掉 Node 20 弃用警告）
- 已知提示：ubuntu-latest 将于 2026-10-19 迁移至 Ubuntu 26

## 任务目标
1. （已完成）定位并修复 `Set up job` 秒失败：经 check-runs annotations 定位为 action SHA 写错，非runner 基础设施故障
2. （已完成）端到端演练验证 PAT 推 tag 能否触发下游 build：演练中发现 checkout 凭据覆盖 PAT 的隐藏缺陷并修复
3. （已完成）全链路实证：detect → bump → PAT push master → push tag <version>-<release> → 触发 build → 发布正式 Release；Release `1.140.06880-60` 已发布且资产完整
4. （已完成）验证 Release 资产完整（vscodiumportable-win64-<version>-<release>.7z、VscodiumPortable.exe、checksums.txt）
5. （后续可选）配置 VT_API_KEY / VT_MONITOR_API_KEY 验证 released.yml；处理 dependabot 4 个 PR

## 关键约束（已踩过的坑，务必遵守）
1. reusable workflow 调用 job 禁止 timeout-minutes：会报 "Unexpected value 'uses'" + "Required property is missing: runs-on"，run 秒失败且无 job。调用方 job 只允许 uses/with/secrets/permissions/strategy/name/concurrency
2. 内置 GITHUB_TOKEN 推送 commit/tag 不会触发下游 workflow（防循环机制），自动更新必须用 PAT（RELEASE_TOKEN）推送
3. 官方 app-build.yml 默认创建 draft:true Release，本项目已本地化并改 draft:false，禁止回退
4. tag 命名约定：<app.version>-<app.release>（与产物名一致，如 1.141.07080-61）
5. workflow 文件要求：无 BOM、无 tab、LF 换行；on 顶层键保持标准写法
6. 版本比较用语义化（compareVersions），排除 draft/prerelease/名称含 alpha|beta|preview|rc 的版本，匹配资产 VSCodium-win32-x64-<tag>.zip
7. **用 PAT 推送的 workflow，actions/checkout 必须设 `persist-credentials: false`**。checkout 默认 persist-credentials:true，会把内置 GITHUB_TOKEN 写入本地 git config 的 `http.https://github.com/.extraheader`，该 header 优先级**高于** push URL 里内嵌的 `x-access-token:$RELEASE_TOKEN`，导致实际以 `github-actions[bot]` 身份推送 → `Permission denied ... denied to github-actions[bot]` + 403，且 RELEASE_TOKEN 从未被使用。注意：把 `permissions: contents: write` 调大是错的（内置 token 推 tag 不触发下游 workflow，违反约束 2）
8. **排查 `Set up job` 失败或 push 403 时，jobs/steps API 不含真实原因**，必须查这两个来源：① `GET /repos/{o}/{r}/check-runs/{job_id}/annotations`（含 "Unable to resolve action" 等真实报错）② `GET /repos/{o}/{r}/actions/runs/{run_id}/logs`（zip，需 Accept: application/vnd.github+json）。症状对照：`Set up job` 秒失败且无 job 无日志 = action SHA 无法解析（校验所有 `uses: xxx@sha` 是否 HTTP 200，SHA 可能只有前 24 位正确）

## 工具与凭据
- 可用：git、curl、gh CLI（若已安装）、GitHub REST API
- GitHub 凭据：优先使用环境变量 GITHUB_TOKEN；若未设置请先询问用户提供，严禁编造；禁止把 token 明文写入任何文件
- 修改 workflow 后推送走本地 git（用户本人认证方式，避免内置 token 防循环限制）

## 验收标准
- auto-update run 结论为 success，或给出稳定复现的根因与已推送的修复
- 有新版时：master 出现 "Update VSCodium to <version>" 提交、tag 存在、build workflow 自动触发且 success、GitHub Releases 出现正式 Release 且资产完整
- 无新版时：no-op 且 success

请逐步执行并汇报每步结果。
*（内容由AI生成，仅供参考）*
