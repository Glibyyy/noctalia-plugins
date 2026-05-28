#!/usr/bin/env bash
# NixOS manager actions — rebuild, gc, git operations.
# Usage: action.sh <action> [args...]
# Actions: rebuild, gc, git-pull, git-push, git-commit

set -euo pipefail
trap '[ -t 0 ] && { echo ""; read -n 1 -s -r -p "Press any key to close..."; }' EXIT

ACTION="${1:?Usage: action.sh rebuild|gc|git-pull|git-push|git-commit [args...]}"
shift

FLAKE_DIR="${NIXOS_MANAGER_FLAKE_DIR:-$HOME/nixos-config}"
FLAKE_DIR="${FLAKE_DIR/#\~/$HOME}"
HOST=$(hostname)

case "$ACTION" in
  rebuild)
    MODE="${1:-switch}"
    cd "$FLAKE_DIR"
    echo "══════════════════════════════════════════════"
    echo "  NixOS Rebuild ($MODE)"
    echo "  Host: $HOST"
    echo "══════════════════════════════════════════════"
    echo ""

    if [[ "$MODE" == "flake" ]]; then
      echo "Updating flake inputs..."
      nix flake update --flake "$FLAKE_DIR"
      echo ""
      MODE="switch"
    fi

    if [[ "$MODE" == "dry" ]]; then
      sudo nixos-rebuild dry-build --flake "$FLAKE_DIR#$HOST" 2>&1
      echo ""
      echo "Dry build complete — no changes applied."
    else
      if sudo nixos-rebuild "$MODE" --flake "$FLAKE_DIR#$HOST" 2>&1; then
        NEW_GEN=$(sudo nix-env --list-generations --profile /nix/var/nix/profiles/system 2>/dev/null \
          | grep '(current)' | awk '{print $1}')

        # Clear QML cache after activation (not for build/boot)
        if [[ "$MODE" != "build" && "$MODE" != "boot" ]]; then
          QML_CACHE="$HOME/.cache/noctalia-qs/qmlcache"
          if [[ -d "$QML_CACHE" ]]; then
            rm -rf "$QML_CACHE"
            echo "  QML cache cleared"
          fi
        fi

        echo ""
        echo "══════════════════════════════════════════════"
        echo "  Done — generation $NEW_GEN ($MODE)"
        echo "══════════════════════════════════════════════"
      else
        echo ""
        echo "══════════════════════════════════════════════"
        echo "  FAILED"
        echo "══════════════════════════════════════════════"
        exit 1
      fi
    fi
    ;;

  gc)
    MODE="${1:-full}"
    echo "══════════════════════════════════════════════"
    echo "  Garbage Collection ($MODE)"
    echo "══════════════════════════════════════════════"
    echo ""

    case "$MODE" in
      full)
        sudo nix-collect-garbage -d 2>&1
        nix-collect-garbage -d 2>&1
        ;;
      keep3)
        sudo nix-env --delete-generations +3 --profile /nix/var/nix/profiles/system 2>&1
        nix-collect-garbage 2>&1
        ;;
      keep5)
        sudo nix-env --delete-generations +5 --profile /nix/var/nix/profiles/system 2>&1
        nix-collect-garbage 2>&1
        ;;
      store)
        nix store gc 2>&1
        ;;
      dry)
        nix-collect-garbage --dry-run 2>&1
        ;;
    esac

    echo ""
    echo "══════════════════════════════════════════════"
    echo "  Done"
    echo "══════════════════════════════════════════════"
    ;;

  git-pull)
    cd "$FLAKE_DIR"
    git pull --rebase 2>&1
    echo "Pull complete."
    ;;

  git-push)
    cd "$FLAKE_DIR"
    git push 2>&1
    echo "Push complete."
    ;;

  git-commit)
    MSG="${1:?commit message required}"
    cd "$FLAKE_DIR"
    git add -A 2>&1
    git commit -m "$MSG" 2>&1
    echo "Committed: $MSG"
    ;;

  git-diff-local)
    cd "$FLAKE_DIR"
    echo "══════════════════════════════════════════════"
    echo "  Local Changes"
    echo "══════════════════════════════════════════════"
    echo ""
    git diff --stat --color 2>&1
    echo ""
    git diff --color 2>&1
    ;;

  git-diff-remote)
    cd "$FLAKE_DIR"
    UPSTREAM=$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || echo "")
    if [ -n "$UPSTREAM" ]; then
      BEHIND=$(git rev-list --count "HEAD..$UPSTREAM" 2>/dev/null || echo 0)
      AHEAD=$(git rev-list --count "$UPSTREAM..HEAD" 2>/dev/null || echo 0)
      if [ "$BEHIND" -gt 0 ]; then
        echo "══════════════════════════════════════════════"
        echo "  $BEHIND commit(s) behind"
        echo "══════════════════════════════════════════════"
        echo ""
        git log --oneline --color "HEAD..$UPSTREAM" 2>&1
        echo ""
        git diff --stat --color "HEAD...$UPSTREAM" 2>&1
        echo ""
        git diff --color "HEAD...$UPSTREAM" 2>&1
      fi
      if [ "$AHEAD" -gt 0 ]; then
        echo "══════════════════════════════════════════════"
        echo "  $AHEAD commit(s) ahead"
        echo "══════════════════════════════════════════════"
        echo ""
        git log --oneline --color "$UPSTREAM..HEAD" 2>&1
        echo ""
        git diff --stat --color "$UPSTREAM...HEAD" 2>&1
        echo ""
        git diff --color "$UPSTREAM...HEAD" 2>&1
      fi
    else
      echo "No upstream configured."
    fi
    ;;

  *)
    echo "Unknown action: $ACTION" >&2
    exit 1
    ;;
esac
