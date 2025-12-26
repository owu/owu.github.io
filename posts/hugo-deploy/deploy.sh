#!/bin/bash

# Hugo static blog deployment script
# 作者 https://owu.github.io
# 版本 2025-12-26 20:00:00

SRC_DIR="/home/develop/owu.github.com"
DST_DIR="/home/develop/owu.github.io"

# 步骤1: 更新SOURCE仓库到main分支最新版本
echo "正在更新 $SRC_DIR 仓库到最新版本..."
cd "$SRC_DIR"
git checkout main
if [ $? -ne 0 ]; then
    echo "切换到main分支失败"
    exit 1
fi

# 重置本地更改，确保与远程仓库一致
git reset --hard
if [ $? -ne 0 ]; then
    echo "重置本地更改失败"
    exit 1
fi

git pull
if [ $? -ne 0 ]; then
    echo "拉取最新代码失败"
    exit 1
fi

# 步骤2: 进入blog目录，执行hugo生成静态博客
echo "正在生成Hugo静态博客..."

hugo build
if [ $? -ne 0 ]; then
    echo "Hugo生成失败"
    exit 1
fi

# 步骤3: 使用git导出干净的public目录代码
echo "正在导出public目录代码..."
TEMP_DIR=$(mktemp -d)

# 确保临时目录在退出时被清理
function cleanup {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# 导出public目录
git archive --format=zip main public --output="$TEMP_DIR/public.zip"
if [ $? -ne 0 ]; then
    echo "导出public目录失败"
    exit 1
fi

# 解压导出的zip文件
unzip -q "$TEMP_DIR/public.zip" -d "$TEMP_DIR"
if [ $? -ne 0 ]; then
    echo "解压public.zip失败"
    exit 1
fi

# 获取解压后的public目录
EXTRACTED_PUBLIC="$TEMP_DIR/public"

# 验证解压后的public目录是否存在且包含文件
if [ ! -d "$EXTRACTED_PUBLIC" ]; then
    echo "错误：解压后未找到public目录"
    exit 1
fi

if [ -z "$(ls -A "$EXTRACTED_PUBLIC")" ]; then
    echo "错误：public目录为空，没有内容可复制"
    exit 1
fi

# 步骤4: 进入DST_DIR目录，拉取最新代码
echo "正在更新 $DST_DIR 仓库到最新版本..."
cd "$DST_DIR"
git checkout main
if [ $? -ne 0 ]; then
    echo "切换到main分支失败"
    exit 1
fi

git pull
if [ $? -ne 0 ]; then
    echo "拉取最新代码失败"
    exit 1
fi

# 步骤5: 删除DST_DIR中除.git以外的所有文件和目录
echo "正在清理 $DST_DIR 目录..."
find "$DST_DIR" -mindepth 1 -maxdepth 1 ! -name ".git" -exec rm -rf {} \;

# 步骤6: 将导出的public目录内容复制到DST_DIR
echo "正在将public目录内容复制到 $DST_DIR ..."
# 使用cp命令的--preserve选项保留文件属性，并确保复制所有内容
cp -r --preserve=all "$EXTRACTED_PUBLIC"/. "$DST_DIR/"
if [ $? -ne 0 ]; then
    echo "复制public目录内容失败"
    exit 1
fi

# 验证目标目录是否包含复制的文件
if [ -z "$(ls -A "$DST_DIR" 2>/dev/null)" ]; then
    echo "错误：目标目录仍然为空，复制可能未成功"
    exit 1
fi

# 步骤7: 清理临时目录
echo "正在清理临时目录..."
rm -rf "$TEMP_DIR"

# 步骤8: 提交并推送到远程仓库
echo "正在将变更提交到远程仓库..."
git add .
if [ $? -ne 0 ]; then
    echo "添加文件到暂存区失败"
    exit 1
fi

git commit -m "Update blog content"
if [ $? -ne 0 ]; then
    echo "提交代码失败"
    exit 1
fi

git push
if [ $? -ne 0 ]; then
    echo "推送代码到远程仓库失败"
    exit 1
fi

# 步骤9: 返回原始目录
cd "$SRC_DIR"

echo "部署完成！"