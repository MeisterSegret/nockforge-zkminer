nockforge zkminer 0.3.3 -- GPU miner for Nockchain (proof-version 3)
===================================================================
Linux x86_64, NVIDIA.

1. QUICK START
--------------
    sha256sum nockforge-zkminer-0.3.3.tar.gz     # compare with the site
    tar xzf nockforge-zkminer-0.3.3.tar.gz && cd nockforge-zkminer-0.3.3
    NOCKPOOL_WALLET=<your payout address> NOCKPOOL_RIG=<name> ./run.sh

Pool endpoint: pool.nockforge.tech:27016, QUIC over UDP, outbound only --
nothing needs to be forwarded inbound. Your login is the payout address
itself: no account, no password, no API token. The miner never sees a private
key, holds none, and cannot move coins.

2. POOL OR SOLO
---------------
Pool: PPLNS over the work of the last 8 network blocks, counted backwards from
the moment a block is found. Your share of that window is your share of the
block, minus the 4 % fee.

Solo: end the rig name with -solo (also "solo" or ".solo"), e.g.
NOCKPOOL_RIG=rig1-solo. The whole block reward is yours when you find one,
minus the same 4 % solo fee. Same endpoint, same miner, same payout path.

Payouts run once a day, at 20:00 UTC, and go straight to your
address once your balance reaches your threshold -- 100 NOCK by default,
adjustable per address at nockforge.tech/miner/<address>. One address, one
mode per rig: pool rigs and solo rigs can run under the same address at once.

3. WHAT YOU NEED
----------------
GPU     NVIDIA. Precompiled kernel images ship for compute capability 7.5,
        8.0, 8.6, 8.9, 9.0, 10.0 and 12.0 -- Turing, Ampere, Ada, Hopper,
        Blackwell; a card outside that list is refused at startup. Verified
        only on the RTX 5090; other cards start but are untested and slower.
VRAM    12 GB minimum, 16 GB recommended, 24 GB or more for the full batch.
        run.sh picks the batch size from what your card reports.
CPU     4 or more free cores.
RAM     8 GB host RAM, 16 GB comfortable. Under WSL2 that is RAM given to the
        guest, not RAM in the machine.
Driver  NVIDIA R580 or newer. No CUDA toolkit needed: libcuda.so.1 is the only
        NVIDIA library the miner loads.
OS      Linux x86_64, glibc 2.38 or newer (Ubuntu 24.04). Windows only through
        WSL2 on the Windows NVIDIA driver -- no Linux GPU driver inside WSL.

4. WHAT IT LOOKS LIKE WHEN IT WORKS
-----------------------------------
    quiver: authenticated, device accepted (linux / <your GPU>)
    LOCAL 51876.5 cand/s (51.88 kp/s) | 1h 51.9 kp/s | 24h 51.7 kp/s | GPU 66 C 520 W | shares 14 accepted 0 rejected | ...
    SHARE ACCEPTED: accepted

The third line is the only proof that you are earning. On the LOCAL line,
accepted must keep up with submitted; REJECTED above 0 is a defect -- stop and
report it with the log. The cand/s figure is a running average since start, so
judge it after ten minutes, not after one.

Completing a share is CPU work, not GPU work: the GPU finds candidates, a CPU
worker turns one into a submittable share. A slow CPU caps your paid work no
matter how fast the card is. If you have idle cores, raise ZKMINER_COMPLETERS.

5. CONFIGURATION
----------------
    NOCKPOOL_WALLET     (required)  your base58 payout address, and your login
    NOCKPOOL_RIG        [rig1]      worker label; -solo selects solo mode
    NOCKPOOL_SERVER     [pool.nockforge.tech:27016]  host:port of the pool
    NOCKPOOL_INSECURE   [0]         1 disables certificate checking
    ZKMINER_MINER_B     [from VRAM] batch width; higher is faster, needs more VRAM
    ZKMINER_COMPLETERS  [4]         parallel share-completion workers (CPU)
    ZKMINER_HIT_QUEUE   [8]         hits that may wait for a completer
    ZKMINER_PIPE_STREAMS[2]         CUDA streams
    ZKMINER_GPU_MODEL   [detected]  reported to the pool, cosmetic
    ZKMINER_COMPLETE_KERNEL, ZKMINER_SNAP_KERNEL  [the .jam files shipped here]
    RUST_LOG            [info]

Connect by NAME. The pool's certificate is issued for pool.nockforge.tech and
carries no IP SAN, so connecting by IP only works with NOCKPOOL_INSECURE=1 --
which turns certificate verification off entirely and is for testing only.

6. PACKAGE CONTENTS AND LICENCE
-------------------------------
    zkminer-miner     the miner (closed source; its own source is not published)
    zkcomplete.jam    Nock kernel used to complete a share
    zksnap.jam        Nock kernel used to build the job snapshot
    run.sh            launcher: checks the driver, picks a batch size
    README.txt        this file
    SHA256SUMS        checksums of every other file (sha256sum -c SHA256SUMS)
    NOTICE            what third-party code is in the binary, on what terms
    THIRD-PARTY.txt   every linked package with version and licence
    LICENSE-MIT, LICENSE-APACHE, LICENSE-MPL-2.0   the texts NOTICE refers to

The Nockchain code inside the binary is dual-licensed MIT OR Apache-2.0, which
permits binary redistribution as long as the licence text travels with it.
Three linked packages are under MPL-2.0; NOTICE names them and says where their
source is. No package in the graph is under GPL, LGPL or AGPL.

This package contains no wallet, no key and no token. If you ever find a key in
a mining package, from us or anyone else, do not run it. There is no warranty
of any kind, including for what the miner earns.
