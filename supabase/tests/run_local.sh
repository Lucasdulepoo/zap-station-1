#!/usr/bin/env bash
# Aplica as migrações em um PostgreSQL local descartável (com stubs do Supabase) e
# executa os testes de RLS. Não precisa de Docker nem de conta Supabase.
#
# Uso:  supabase/tests/run_local.sh
# Requer: binários do PostgreSQL 15+ (initdb, pg_ctl, psql). Se executado como root,
#         reexecuta como o usuário definido em PGTEST_USER (padrão: postgres).
set -euo pipefail

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
HERE="$(dirname "$SELF")"
MIGRATIONS="${MIGRATIONS_DIR:-$HERE/../migrations}"

if [ "$(id -u)" -eq 0 ]; then
  exec runuser -u "${PGTEST_USER:-postgres}" -- env TMPDIR="${TMPDIR:-/tmp}" bash "$SELF" "$@"
fi

PGBIN="$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | sort -V | tail -1 || true)"
if [ -z "$PGBIN" ] && command -v initdb >/dev/null 2>&1; then
  PGBIN="$(dirname "$(command -v initdb)")"
fi
[ -n "$PGBIN" ] || { echo "PostgreSQL (initdb/pg_ctl/psql) nao encontrado." >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/zap-pgtest.XXXXXX")"
DATA="$WORK/data"
SOCK="$WORK/sock"
mkdir -p "$SOCK"

cleanup() {
  "$PGBIN/pg_ctl" -D "$DATA" -m immediate stop >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

"$PGBIN/initdb" -D "$DATA" -U postgres --auth=trust -E UTF8 --locale=C.UTF-8 >/dev/null
"$PGBIN/pg_ctl" -D "$DATA" -l "$WORK/pg.log" -w \
  -o "-c listen_addresses='' -c unix_socket_directories='$SOCK' -c fsync=off" start >/dev/null

PSQL=("$PGBIN/psql" -h "$SOCK" -U postgres -v ON_ERROR_STOP=1 -X -q)

"${PSQL[@]}" -d postgres -c "create database zap_test" >/dev/null
PSQL+=( -d zap_test )

echo "==> stubs do Supabase"
"${PSQL[@]}" -f "$HERE/00_stubs.sql"

for f in $(ls "$MIGRATIONS"/*.sql | sort); do
  echo "==> migracao $(basename "$f")"
  "${PSQL[@]}" -f "$f"
done

echo "==> fixtures"
"${PSQL[@]}" -f "$HERE/10_fixtures.sql"

echo "==> testes RLS"
OUT="$WORK/tests.out"
if ! "${PSQL[@]}" -f "$HERE/20_rls_tests.sql" >"$OUT" 2>&1; then
  cat "$OUT"
  echo "FALHOU" >&2
  exit 1
fi

cat "$OUT"
PASS=$(grep -c 'PASS:' "$OUT" || true)
grep -q ALL_TESTS_COMPLETED "$OUT" || { echo "testes nao chegaram ao fim" >&2; exit 1; }
if grep -q 'FAIL:' "$OUT"; then echo "ha falhas" >&2; exit 1; fi
echo "==> OK: $PASS verificacoes aprovadas"
