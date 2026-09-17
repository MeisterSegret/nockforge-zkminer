#!/usr/bin/env bash
#
# nockforge zkminer 0.4.0 — launcher
#
# Usage:  NOCKPOOL_WALLET=<your payout address> ./run.sh
#
# Everything below is overridable from the environment. Read README.txt first,
# especially the section on NOCKPOOL_INSECURE.
#
set -u
# The base58 check below uses character RANGES, and outside the C locale a
# range like A-H can collate to something else entirely. Pin it.
export LC_ALL=C

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

die() { printf '\n[zkminer] ERROR: %s\n\n' "$*" >&2; exit 1; }
note() { printf '[zkminer] %s\n' "$*"; }

# ---------------------------------------------------------------- 1. wallet
if [ -z "${NOCKPOOL_WALLET:-}" ]; then
  cat >&2 <<'EOT'

[zkminer] ERROR: NOCKPOOL_WALLET is not set.

  Set it to the nockchain payout address you want to be paid at. It is also
  your login at the pool -- there is no separate password or API token.

      NOCKPOOL_WALLET=<your base58 payout address> ./run.sh

  Do not use anyone else's address. Whatever you put here is where the coins go.

EOT
  exit 1
fi

# A wrong address is not caught by anything downstream: the pool answers a
# malformed login with a dropped connection, so the miner would boot its
# kernel, spin up the GPU and then reconnect forever with "auth read:
# connection lost" -- burning power and telling you nothing. Check the shape
# here, before any of that happens.
#
# base58 as Nockchain uses it: no 0, O, I or l. Real payout addresses are 55
# characters; the range below is deliberately wider so a future format is not
# rejected out of hand.
case "$NOCKPOOL_WALLET" in
  *[!1-9A-HJ-NP-Za-km-z]*)
    die "NOCKPOOL_WALLET contains characters that cannot occur in a base58 address.
     Got: $NOCKPOOL_WALLET
     A payout address uses digits 1-9 and letters, but never 0, O, I or l." ;;
esac
WALLET_LEN=${#NOCKPOOL_WALLET}
if [ "$WALLET_LEN" -lt 40 ] || [ "$WALLET_LEN" -gt 80 ]; then
  die "NOCKPOOL_WALLET is $WALLET_LEN characters long; a payout address is 55.
     Got: $NOCKPOOL_WALLET"
fi
if [ "$WALLET_LEN" -ne 55 ]; then
  note "WARNING: your address is $WALLET_LEN characters, not the usual 55."
  note "  Check it before you leave this running -- a valid-looking but wrong"
  note "  address mines happily and pays someone else."
fi

# ---------------------------------------------------------------- 2. pool
# The HOSTNAME, not the IP: the pool's certificate is issued for
# pool.nockforge.tech and carries no IP SAN, so verification FAILS against
# 185.213.25.194:27016. The IP still works as a fallback, but only together
# with NOCKPOOL_INSECURE=1 -- see README.txt section 5.
export NOCKPOOL_SERVER="${NOCKPOOL_SERVER:-pool.nockforge.tech:27016}"
# NOCKPOOL_RIG is the worker label. A rig name ending in -solo (also "solo" or
# ".solo") selects solo mining instead of pool mining -- same endpoint, same
# payout path, whole block reward minus the solo fee.
export NOCKPOOL_RIG="${NOCKPOOL_RIG:-rig1}"

# NOCKPOOL_INSECURE=1 turns OFF verification of the pool's TLS certificate.
# The pool serves a real Let's Encrypt certificate for pool.nockforge.tech,
# so the default is 0: verify, like any other TLS client. Setting it to 1
# installs a verifier that returns "valid" for every certificate without
# looking at it -- traffic stays encrypted, but anyone who can redirect your
# UDP traffic can impersonate the pool. Only reason to do that: you are
# connecting by IP, or to a pool of your own with a self-signed certificate.
export NOCKPOOL_INSECURE="${NOCKPOOL_INSECURE:-0}"
if [ "$NOCKPOOL_INSECURE" != "0" ]; then
  note "NOCKPOOL_INSECURE=$NOCKPOOL_INSECURE -- the pool's TLS certificate is NOT verified."
  note "  You do not need this against pool.nockforge.tech. See README.txt section 5."
fi
# Verifying by IP cannot work, and the failure looks like a network problem
# rather than a name problem. Say so before the GPU spins up.
case "$NOCKPOOL_SERVER" in
  [0-9]*.[0-9]*.[0-9]*.[0-9]*:*|\[*)
    if [ "$NOCKPOOL_INSECURE" = "0" ]; then
      die "NOCKPOOL_SERVER=$NOCKPOOL_SERVER is an IP address, and the pool's certificate is
     issued for the NAME pool.nockforge.tech only (no IP SAN). With
     NOCKPOOL_INSECURE=0 the handshake will fail with
     'certificate not valid for name ...'.
     Use  NOCKPOOL_SERVER=pool.nockforge.tech:27016  (recommended), or keep the
     IP and add NOCKPOOL_INSECURE=1 to skip verification."
    fi ;;
esac

# ---------------------------------------------------------------- 3. prover kernel
# Since the Anthropos fork (proof-version 5) the GPU grinds nonces on its own;
# the Nock kernel below is used only when a nonce meets the NETWORK target, to
# build the full proof for that one block. It is the stock miner kernel of the
# Nockchain 0.1.17 (Anthropos) release.
export ZKMINER_V5_KERNEL="${ZKMINER_V5_KERNEL:-$HERE/miner.jam}"
[ -f "$ZKMINER_V5_KERNEL" ] || die "missing $ZKMINER_V5_KERNEL (unpack the whole tarball)"

# ---------------------------------------------------------------- 4. driver
command -v nvidia-smi >/dev/null 2>&1 \
  || die "nvidia-smi not found. An NVIDIA driver (R580 or newer, i.e. CUDA 13 capable) is required."

DRV="$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1)"
[ -n "$DRV" ] || die "nvidia-smi found no GPU. On Windows you must run this inside WSL2 with GPU support."
DRV_MAJ="${DRV%%.*}"
if [ "${DRV_MAJ:-0}" -lt 580 ] 2>/dev/null; then
  die "driver $DRV is too old. This miner uses the CUDA 13.0 driver API; you need R580 or newer."
fi
note "driver $DRV"

# ---------------------------------------------------------------- 5. kernel images
# 0.4.0 ships precompiled CUDA kernel images (cubins) for compute capabilities 8.0,
# 8.6, 8.9, 9.0, 10.0 and 12.0 (Ampere and newer) inside the binary. Nothing is compiled at startup,
# so libnvrtc.so.13 -- and with it the whole CUDA toolkit -- is not needed: the NVIDIA
# driver (libcuda.so.1) is the only NVIDIA library this miner loads. A card whose
# compute capability is not in that list is refused by name at startup.
#
# The grind needs well under 1 GB of VRAM; there is no batch size to pick any more.

# ---------------------------------------------------------------- 6. tuning
# ZKMINER_V5_COMPLETERS: how many Nock kernels stay booted to prove a block-class
# hit (one is plenty; each takes ~2 s to boot and one CPU core for ~30 s per proof).
export ZKMINER_V5_COMPLETERS="${ZKMINER_V5_COMPLETERS:-1}"
export ZKMINER_GPU_MODEL="${ZKMINER_GPU_MODEL:-$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)}"
export RUST_LOG="${RUST_LOG:-info}"

note "pool $NOCKPOOL_SERVER  rig $NOCKPOOL_RIG"
note "starting -- watch for 'SHARE ACCEPTED'. Ctrl-C to stop."
echo

exec "$HERE/zkminer-miner" "$@"
