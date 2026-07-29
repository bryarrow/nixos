#!/usr/bin/env bash
set -euo pipefail

mutter_version="${1:?缺少 mutter 版本}"
mutter_api_version="${2:?缺少 mutter API 版本}"

repo_mutter_req="$(
  sed -n "s/^mutter_req = '>= \([0-9][0-9]*\)\..*'$/\1/p" meson.build
)"
repo_mutter_api_version="$(
  sed -n "s/^mutter_api_version = '\([0-9][0-9]*\)'$/\1/p" meson.build
)"
system_mutter_major="${mutter_version%%.*}"

if [[ -z "${repo_mutter_req}" || -z "${repo_mutter_api_version}" ]]; then
  echo "无法从 meson.build 读取 mutter 版本字段" >&2
  exit 1
fi

# 复用 Blur my Shell 上游 rounded_blur_build.sh 的版本换算逻辑，
# 但版本值来自 nixpkgs，而不是在构建期间运行 mutter 或修改已安装目录。
if [[ "${system_mutter_major}" -ge "${repo_mutter_req}" ]]; then
  diff_value="$(echo "${system_mutter_major} - ${repo_mutter_req}" | bc)"
  target_api_version="$(echo "${repo_mutter_api_version} + ${diff_value}" | bc)"
else
  diff_value="$(echo "${repo_mutter_req} - ${system_mutter_major}" | bc)"
  target_api_version="$(echo "${repo_mutter_api_version} - ${diff_value}" | bc)"
fi

if [[ "${target_api_version}" != "${mutter_api_version}" ]]; then
  echo "上游版本换算得到 mutter API ${target_api_version}，但 nixpkgs 暴露的是 ${mutter_api_version}" >&2
  echo "这里使用 nixpkgs 的值，因为它是本次构建中权威的 pkg-config 后缀。" >&2
  target_api_version="${mutter_api_version}"
fi

sed -i \
  -e "s/mutter_api_version = '${repo_mutter_api_version}'/mutter_api_version = '${target_api_version}'/" \
  -e "s/mutter_req = '>= ${repo_mutter_req}\\.0'/mutter_req = '>= ${system_mutter_major}.0'/" \
  -e "s/dependency('libmutter-${repo_mutter_api_version}')/dependency('libmutter-${target_api_version}')/" \
  meson.build
