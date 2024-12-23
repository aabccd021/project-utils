git add -A >/dev/null

if nix flake metadata >/dev/null 2>&1; then
  start=$(date +%s)
  nix fmt
  echo "'nix fmt' finished successfully in $(($(date +%s) - start))s"
fi

git add -A >/dev/null

if nix flake metadata >/dev/null 2>&1; then
  start=$(date +%s)
  nix flake check --log-lines 200 --quiet || (git reset >/dev/null && exit 1)
  echo "'nix flake check' finished successfully in $(($(date +%s) - start))s"
fi

flag=${1:-}

if [ "$flag" = "--no-commit" ]; then
  git reset >/dev/null
  exit 0
fi

new_files=$(git diff --cached --name-only --diff-filter=A)
if [ -n "$new_files" ]; then
  echo "New file(s) detected!"
  echo
  echo "$new_files"
  echo
  printf "Are you sure this file(s) are neccessary? [y/n]: "
  read -r answer
  last_char=${answer#"${answer%?}"}
  if [ "$last_char" != "y" ]; then
    echo "Aborted"
    git reset >/dev/null
    exit 1
  fi
fi

start=$(date +%s)

if [ -z "$OPENAI_API_KEY" ]; then
  echo "OPENAI_API_KEY is not set"
  exit 1
fi

timeout 10 ai-commit --auto-commit >/dev/null 2>&1 ||
  git commit --all --message 'checkpoint'

echo "Commit message generated successfully in $(($(date +%s) - start))s"

start=$(date +%s)

git pull --quiet --rebase
git push --quiet

echo "Respository pushed successfully in $(($(date +%s) - start))s"
