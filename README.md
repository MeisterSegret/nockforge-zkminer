# nockforge-zkminer

GPU miner for [Nockchain](https://nockchain.org) (proof-version 3), NVIDIA only.
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
curl -fsSLO https://github.com/MeisterSegret/nockforge-zkminer/releases/latest/download/nockforge-zkminer-0.3.3.tar.gz
sha256sum nockforge-zkminer-0.3.3.tar.gz     # must match SHA256SUMS on the release and on the site
tar xzf nockforge-zkminer-0.3.3.tar.gz && cd nockforge-zkminer-0.3.3
NOCKPOOL_WALLET=<your payout address> NOCKPOOL_RIG=<name> ./run.sh
```

Your payout address is your login: no account, no password, no API token. The
miner never sees a private key.

## What you need

- NVIDIA GPU, compute capability 7.5 … 12.0 (Turing through Blackwell), 12 GB
  VRAM minimum. Verified on the RTX 5090: 51–52 kp/s at 520 W.
- NVIDIA driver R580 or newer. No CUDA toolkit.
- Linux x86_64, glibc 2.38+ (Ubuntu 24.04). Windows through WSL2.
- 4 free CPU cores, 8 GB host RAM.

Everything else — pool vs. solo, payouts, tuning, troubleshooting — is in the
`README.txt` that ships inside the tarball.

## Pool

- Endpoint `pool.nockforge.tech:27016` (QUIC/UDP, TLS, outbound only)
- Pool mode: PPLNS, 4 % fee. Solo mode: rig name ending in `-solo`, whole block
  minus 4 %.
- Payouts daily at 20:00 UTC from 100 NOCK.
- Stats and per-address pages: <https://nockforge.tech>

## Verifying a release

```bash
sha256sum -c SHA256SUMS          # the tarball against the release checksum
tar xzf nockforge-zkminer-*.tar.gz && cd nockforge-zkminer-*/
sha256sum -c SHA256SUMS          # every file inside the package
```

Issues and hashrate reports: open an issue here.
