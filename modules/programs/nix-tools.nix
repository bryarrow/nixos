{ pkgs, ... }:

{
  # nom（nix-output-monitor）：把 nix 的构建日志渲染成依赖树，同时提供
  # `nom build` / `nom shell` 这些入口；`nixos-rebuild` 的自动接管见下面。
  environment.systemPackages = [ pkgs.nix-output-monitor ];

  # 让交互式的 `nixos-rebuild` 自动把输出交给 nom。
  #
  # NixOS 的 tools 模块把 `config.system.build.nixos-rebuild`（即
  # pkgs.nixos-rebuild-ng）放进 environment.systemPackages，所以在 overlay 里包住
  # nixos-rebuild-ng，就从 PATH 层面覆盖了 `nixos-rebuild`，同时保留它自带的
  # man page 和 shell 补全。
  #
  # 包装只改入口脚本：postFixup 在 wrapPythonPrograms 之后运行，把真正的入口挪到
  # 同一输出目录的 .nixos-rebuild-unwrapped，新脚本用绝对路径调用它。之所以要绝对
  # 路径，是因为 nixos-rebuild 会 re-exec 进新构建出来的 `*/bin/nixos-rebuild`，
  # 相对 $0 会解析到旧一代；写死自身 store 路径后，新版本会调用它自己的 unwrapped。
  nixpkgs.overlays = [
    (final: prev: {
      nixos-rebuild-ng = prev.nixos-rebuild-ng.overrideAttrs (old: {
        postFixup = (old.postFixup or "") + ''
          mv "$out/bin/nixos-rebuild" "$out/bin/.nixos-rebuild-unwrapped"

          cat > "$out/bin/nixos-rebuild" <<'WRAPPER'
#!@shell@
# 由 modules/programs/nix-tools.nix 生成：把 nixos-rebuild 的输出交给 nom 画构建树。
nom=@nom@
real=@real@

# 非交互（CI、重定向、`| tee`）和手动关闭时保持原始输出。
if [ ! -t 1 ] || [ x"$NIXOS_REBUILD_NOM" = x0 ]; then
  exec "$real" "$@"
fi

# 只接管真正会构建/下载的动作；edit、repl、list-generations 需要原始终端，
# --help、--json、--log-format 要么是给人看的说明，要么要求机器可读输出。
use_nom=
for arg in "$@"; do
  case "$arg" in
    switch|boot|test|build|dry-build|dry-run|dry-activate|build-vm|build-vm-with-bootloader|build-image)
      use_nom=1
      ;;
    --help|-h|--version|-V|--json|--log-format|--log-format=*)
      exec "$real" "$@"
      ;;
  esac
done
[ -n "$use_nom" ] || exec "$real" "$@"

# nixos-rebuild 会 re-exec 进新构建出来的版本。那时它的 stdout 就是下面这根管道
# （不是终端），前面的 `-t 1` 会让新包装器只透传，所以不会叠出第二个 nom。
set -o pipefail
"$real" "$@" 2>&1 | "$nom"
WRAPPER

          substituteInPlace "$out/bin/nixos-rebuild" \
            --subst-var-by shell ${final.runtimeShell} \
            --subst-var-by nom ${final.nix-output-monitor}/bin/nom \
            --subst-var-by real "$out/bin/.nixos-rebuild-unwrapped"
          chmod +x "$out/bin/nixos-rebuild"
        '';
      });
    })
  ];
}
