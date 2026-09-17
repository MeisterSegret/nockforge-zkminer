# nockforge-zkminer

GPU miner for [Nockchain](https://nockchain.org) (proof-version 5, Anthropos), NVIDIA only.
Built for and shipped by the [NockForge](https://nockforge.tech) mining pool.

**This repository is binary-only.** The miner's source is not published; what
you find here is the launcher, the notices for the third-party code inside the
binary, and the releases. See [`NOTICE`](NOTICE) and
[`THIRD-PARTY.txt`](THIRD-PARTY.txt).

## Download

Every release is a single tarball with its checksum, published twice: on the
[Releases](../../releases) page here and at <https://nockforge.tech/#download>.
Both are the same file — compare the sha256 against both places before you run
it.

```bash
curl -fsSLO https://github.com/MeisterSegret/nockforge-zkminer/releases/latest/download/nockforge-zkminer-0.4.0.tar.gz
sha256sum nockforge-zkminer-0.4.0.tar.gz     # must match SHA256SUMS on the release and on the site
tar xzf nockforge-zkminer-0.4.0.tar.gz && cd nockforge-zkminer-0.4.0
NOCKPOOL_WALLET=<your payout address> NOCKPOOL_RIG=<name> ./run.sh
```

Your payout address is your login: no account, no password, no API token. The
miner never sees a private key.

## What you need

- NVIDIA GPU, compute capability 8.0 … 12.0 (Ampere through Blackwell), under
  1 GB VRAM. Verified on the RTX 5090: 61.9 M nonces/s at 540 W.
- NVIDIA driver R580 or newer. No CUDA toolkit.
- Linux x86_64, glibc 2.38+ (Ubuntu 24.04). Windows through WSL2.
- 1 free CPU core, 4 GB host RAM.

Everything else — pool vs. solo, payouts, tuning, troubleshooting — is in the
`README.txt` that ships inside the tarball.

## Pool

- Endpoint `pool.nockforge.tech:27016` (QUIC/UDP, TLS, outbound only)
- Pool mode: PPLNS, 2 % fee. Solo mode: rig name ending in `-solo`, whole block
  minus 2 %.
- Payouts daily at 20:00 UTC from 100 NOCK.
- Stats and per-address pages: <https://nockforge.tech>

## Verifying a release

```bash
sha256sum -c SHA256SUMS          # the tarball against the release checksum
tar xzf nockforge-zkminer-*.tar.gz && cd nockforge-zkminer-*/
sha256sum -c SHA256SUMS          # every file inside the package
```

Issues and hashrate reports: open an issue here.
