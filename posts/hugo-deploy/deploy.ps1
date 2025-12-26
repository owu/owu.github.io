# Hugo static blog deployment script
# 作者 https://owu.github.io
# 版本 2025-12-26 20:00:00

$SRC_DIR = "D:\develop\owu.github.com"
$DST_DIR = "D:\develop\owu.github.io"

# 步骤1: 更新SOURCE仓库到main分支最新版本
Write-Host "正在更新 $SRC_DIR 仓库到最新版本..."
Set-Location -Path $SRC_DIR
git checkout main
if ($LASTEXITCODE -ne 0) {
    Write-Host "切换到main分支失败" -ForegroundColor Red
    exit 1
}

# 重置本地更改，确保与远程仓库一致
git reset --hard
if ($LASTEXITCODE -ne 0) {
    Write-Host "重置本地更改失败" -ForegroundColor Red
    exit 1
}

git pull
if ($LASTEXITCODE -ne 0) {
    Write-Host "拉取最新代码失败" -ForegroundColor Red
    exit 1
}

# 步骤2: 进入blog目录，执行hugo生成静态博客
Write-Host "正在生成Hugo静态博客..."
hugo build
if ($LASTEXITCODE -ne 0) {
    Write-Host "Hugo生成失败" -ForegroundColor Red
    exit 1
}

# 步骤3: 使用git导出干净的public目录代码
Write-Host "正在导出public目录代码..."
$TEMP_DIR = New-TemporaryFile | ForEach-Object { $_.FullName -replace '\.tmp$', '' }
New-Item -ItemType Directory -Path $TEMP_DIR | Out-Null


# 导出public目录
git archive --format=zip main public --output="$TEMP_DIR\public.zip"
if ($LASTEXITCODE -ne 0) {
    Write-Host "导出public目录失败" -ForegroundColor Red
    Remove-Item -Path $TEMP_DIR -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

# 解压导出的zip文件
Expand-Archive -Path "$TEMP_DIR\public.zip" -DestinationPath $TEMP_DIR -Force
$EXTRACTED_PUBLIC = Join-Path -Path $TEMP_DIR -ChildPath "public"

# 调试：检查EXTRACTED_PUBLIC目录是否存在及其内容
Write-Host "调试：EXTRACTED_PUBLIC路径: $EXTRACTED_PUBLIC"
if (Test-Path -Path $EXTRACTED_PUBLIC) {
    Write-Host "调试：EXTRACTED_PUBLIC目录存在"
    Write-Host "调试：EXTRACTED_PUBLIC目录内容:"
    Get-ChildItem -Path $EXTRACTED_PUBLIC -Force
} else {
    Write-Host "调试：EXTRACTED_PUBLIC目录不存在" -ForegroundColor Red
    exit 1
}

# 步骤4: 进入DST_DIR目录，拉取最新代码
Write-Host "正在更新 $DST_DIR 仓库到最新版本..."
Set-Location -Path $DST_DIR
git checkout main
if ($LASTEXITCODE -ne 0) {
    Write-Host "切换到main分支失败" -ForegroundColor Red
    Remove-Item -Path $TEMP_DIR -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

git pull
if ($LASTEXITCODE -ne 0) {
    Write-Host "拉取最新代码失败" -ForegroundColor Red
    Remove-Item -Path $TEMP_DIR -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

# 步骤5: 删除DST_DIR中除.git以外的所有文件和目录
Write-Host "正在清理 $DST_DIR 目录..."
Get-ChildItem -Path $DST_DIR -Exclude ".git" -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

# 步骤6: 将导出的public目录内容复制到DST_DIR
Write-Host "正在将public目录内容复制到 $DST_DIR ..."
# 使用*来复制public目录内的所有内容（包括子目录和隐藏文件）
Copy-Item -Path "$EXTRACTED_PUBLIC\*" -Destination $DST_DIR -Recurse -Force
if ($LASTEXITCODE -ne 0) {
    Write-Host "复制public目录内容失败" -ForegroundColor Red
    Remove-Item -Path $TEMP_DIR -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

# 验证目标目录是否包含复制的文件
if ((Get-ChildItem -Path $DST_DIR -Exclude ".git" -Force | Measure-Object).Count -eq 0) {
    Write-Host "错误：目标目录仍然为空，复制可能未成功" -ForegroundColor Red
    Remove-Item -Path $TEMP_DIR -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

# 步骤7: 清理临时目录
Remove-Item -Path $TEMP_DIR -Recurse -Force -ErrorAction SilentlyContinue

# 步骤8: 提交并推送到远程仓库
Write-Host "正在将变更提交到远程仓库..."
git add .
if ($LASTEXITCODE -ne 0) {
    Write-Host "添加文件到暂存区失败" -ForegroundColor Red
    exit 1
}

git commit -m "Update blog content"
if ($LASTEXITCODE -ne 0) {
    Write-Host "提交代码失败" -ForegroundColor Red
    exit 1
}

git push
if ($LASTEXITCODE -ne 0) {
    Write-Host "推送代码到远程仓库失败" -ForegroundColor Red
    exit 1
}

# 步骤9: 返回原始目录
Set-Location -Path $SRC_DIR

Write-Host "部署完成！" -ForegroundColor Green