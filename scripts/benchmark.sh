#!/bin/bash
# Mede a memória e a CPU do Canopy em cenários fixos, com o build de Release.
# Usado pelo CI e também roda num Mac com o Xcode (feche o Canopy antes).
#
#   scripts/benchmark.sh                 todos os cenários
#   scripts/benchmark.sh music timer     só alguns
#
# CPU é a média de um núcleo no intervalo medido, como no Monitor de Atividade.
# Memória é o "physical footprint", a mesma coluna Memória do Monitor de Atividade.
set -euo pipefail
cd "$(dirname "$0")/.."

SCENARIOS=("$@")
if [ ${#SCENARIOS[@]} -eq 0 ]; then
  SCENARIOS=(idle music music-expanded timer privacy home)
fi
WARMUP=${WARMUP:-10}
WINDOW=${WINDOW:-30}
BUILD=${BUILD_DIR:-build/benchmark}
SAMPLE=${SAMPLE:-music music-expanded timer privacy}

xcodebuild build \
  -project Canopy.xcodeproj \
  -scheme Canopy \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$BUILD" \
  CODE_SIGNING_ALLOWED=NO \
  'SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) BENCHMARK' \
  -quiet
APP="$BUILD/Build/Products/Release/Canopy.app/Contents/MacOS/Canopy"

# "1:02.34" ou "1:02:03.45" em segundos.
seconds() {
  echo "$1" | awk -F: '{ if (NF == 3) print $1 * 3600 + $2 * 60 + $3; else print $1 * 60 + $2 }'
}

results=()
for scenario in "${SCENARIOS[@]}"; do
  log="$BUILD/$scenario.log"
  "$APP" -benchmarkScenario "$scenario" >"$log" 2>&1 &
  pid=$!
  sleep "$WARMUP"
  if ! kill -0 "$pid" 2>/dev/null; then
    echo "::error::o Canopy fechou no cenário $scenario"
    cat "$log"
    exit 1
  fi
  start=$(seconds "$(ps -o time= -p "$pid" | tr -d ' ')")
  sleep "$WINDOW"
  end=$(seconds "$(ps -o time= -p "$pid" | tr -d ' ')")
  cpu=$(awk -v a="$start" -v b="$end" -v w="$WINDOW" 'BEGIN { printf "%.2f", (b - a) * 100 / w }')

  summary=$(vmmap --summary "$pid" 2>/dev/null || true)
  footprint=$(echo "$summary" | awk -F: '/^Physical footprint:/ { gsub(/ /, "", $2); print $2 }')
  peak=$(echo "$summary" | awk -F: '/^Physical footprint \(peak\):/ { gsub(/ /, "", $2); print $2 }')
  results+=("$(printf '%-16s %8s%% %10s %10s' "$scenario" "$cpu" "${footprint:-?}" "${peak:-?}")")

  echo "=== $scenario"
  grep '^benchmark:' "$log" || true
  # Onde a CPU vai, para os cenários que animam.
  if [[ " $SAMPLE " == *" $scenario "* ]]; then
    sample "$pid" 3 -mayDie -file "$BUILD/$scenario.sample.txt" >/dev/null 2>&1 || true
    awk '/^Sort by top of stack/ { show = 1 } show && n < 18 { print; n++ }' "$BUILD/$scenario.sample.txt" 2>/dev/null || true
  fi
  echo "$summary" | grep -E '^(MALLOC|IOSurface|IOAccelerator|CoreAnimation|__DATA|TOTAL)' | head -12 || true

  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
done

echo
printf '%-16s %9s %10s %10s\n' "cenário" "CPU" "memória" "pico"
printf '%s\n' "${results[@]}"

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "| cenário | CPU | memória | pico |"
    echo "|---|---|---|---|"
    for line in "${results[@]}"; do
      echo "$line" | awk '{ printf "| %s | %s | %s | %s |\n", $1, $2, $3, $4 }'
    done
  } >>"$GITHUB_STEP_SUMMARY"
fi
