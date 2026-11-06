# 已停用的 GitHub Actions

按项目约定，测试在云环境中运行：`python3 tools/run_tests.py --suite all --jobs 2`。

`godot-tests.yml` 保留作备份，位于此目录时不会被 GitHub Actions 执行。只有用户要求重新启用时，才将它移回 `.github/workflows/`。
