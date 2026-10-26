#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
if [ ! -d "$ROOT/dist/听写.app" ]; then
    /bin/bash "$ROOT/scripts/build-app.sh"
fi
open "$ROOT/dist/听写.app"
