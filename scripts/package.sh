#!/bin/bash
# Gera o Canopy.app de Release, assina e monta o Canopy-<versão>.dmg em build/package.
# Roda num Mac com o Xcode instalado (o CI usa o mesmo script).
#
#   scripts/package.sh              gera o .app e o .dmg
#   scripts/package.sh --install    também instala em /Applications e abre o app
#
# Assinatura: usa o primeiro certificado que achar no Chaveiro, nesta ordem:
#   1. Developer ID Application   (conta paga: abre em qualquer Mac, com notarização)
#   2. Apple Development          (Apple ID grátis: as permissões não caem a cada build)
#   3. ad hoc                     (sem certificado: só para testar)
# Para escolher outro, rode com CANOPY_SIGN_IDENTITY="nome do certificado" (ou "-" para ad hoc).
#
# Notarização (só com Developer ID): salve a senha uma vez com
#   xcrun notarytool store-credentials canopy --apple-id <email> --team-id <TEAM>
# e rode com NOTARY_PROFILE=canopy.
set -euo pipefail
cd "$(dirname "$0")/.."

INSTALL=0
for arg in "$@"; do
  case "$arg" in
    --install) INSTALL=1 ;;
    *) echo "opção desconhecida: $arg" >&2; exit 2 ;;
  esac
done

OUT=${BUILD_DIR:-build/package}
rm -rf "$OUT"
mkdir -p "$OUT"

echo "==> Build de Release"
xcodebuild build \
  -project Canopy.xcodeproj \
  -scheme Canopy \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$OUT/DerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  -quiet
APP="$OUT/Canopy.app"
ditto "$OUT/DerivedData/Build/Products/Release/Canopy.app" "$APP"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")

if [ -z "${CANOPY_SIGN_IDENTITY+x}" ]; then
  identities=$(security find-identity -v -p codesigning 2>/dev/null || true)
  CANOPY_SIGN_IDENTITY=$(echo "$identities" | sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p' | head -1)
  if [ -z "$CANOPY_SIGN_IDENTITY" ]; then
    CANOPY_SIGN_IDENTITY=$(echo "$identities" | sed -n 's/.*"\(Apple Development: .*\)"/\1/p' | head -1)
  fi
  CANOPY_SIGN_IDENTITY=${CANOPY_SIGN_IDENTITY:--}
fi

echo "==> Assinando com: $([ "$CANOPY_SIGN_IDENTITY" = "-" ] && echo "ad hoc" || echo "$CANOPY_SIGN_IDENTITY")"
sign_flags=(--force --options runtime --sign "$CANOPY_SIGN_IDENTITY")
if [[ "$CANOPY_SIGN_IDENTITY" == "Developer ID Application:"* ]]; then
  sign_flags+=(--timestamp)
else
  sign_flags+=(--timestamp=none)
fi
# O que vai dentro do app primeiro, o app por último.
if [ -d "$APP/Contents/Frameworks" ]; then
  find "$APP/Contents/Frameworks" -mindepth 1 -maxdepth 1 -print0 | while IFS= read -r -d '' item; do
    codesign "${sign_flags[@]}" "$item"
  done
fi
codesign "${sign_flags[@]}" --entitlements Config/Canopy.entitlements "$APP"
codesign --verify --strict "$APP"

echo "==> Montando o .dmg"
DMG="$OUT/Canopy-$VERSION.dmg"
STAGE="$OUT/dmg"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/Canopy.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname Canopy -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
rm -rf "$STAGE"
if [ "$CANOPY_SIGN_IDENTITY" != "-" ]; then
  codesign --force --sign "$CANOPY_SIGN_IDENTITY" "$DMG"
fi

if [ -n "${NOTARY_PROFILE:-}" ]; then
  if [[ "$CANOPY_SIGN_IDENTITY" != "Developer ID Application:"* ]]; then
    echo "A notarização precisa de um certificado Developer ID Application." >&2
    exit 1
  fi
  echo "==> Notarizando (leva alguns minutos)"
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
fi

if [ "$INSTALL" -eq 1 ]; then
  echo "==> Instalando em /Applications"
  # Fecha o Canopy que estiver aberto (inclusive o que o Xcode abriu).
  pkill -x Canopy 2>/dev/null && sleep 1 || true
  rm -rf /Applications/Canopy.app
  ditto "$APP" /Applications/Canopy.app
  open /Applications/Canopy.app
fi

echo
echo "Pronto: $APP"
echo "        $DMG"
