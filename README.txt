nockforge zkminer 0.6.7 -- GPU miner for Nockchain (proof-version 5, Anthropos)
================================================================================
Linux x86_64, NVIDIA.

1. QUICK START
--------------
    sha256sum nockforge-zkminer-0.6.7.tar.gz     # compare with the site
    tar xzf nockforge-zkminer-0.6.7.tar.gz && cd nockforge-zkminer-0.6.7
    ./nockforge --wallet <your payout address>

That is the whole setup. Two more switches cover almost every rig:

    ./nockforge --wallet <address> --device rig1        # name this rig in the pool
    ./nockforge --wallet <address> --device rig1 --gpus 0,2

    --device <name>    worker label shown in the pool (default: rig1). On a
                       multi-GPU box the miner appends "-gpu<i>" per card.
    --gpus <list>      which cards: "0", "0,2" or "all" (default: all).
    --clock-offset <n> GPU core clock offset in MHz (default: off, see 5a)
    --pool <host:port>, --solo, --insecure, --help   -> ./nockforge --help

`run.sh` is still there and still works. `nockforge` only sets the NOCKPOOL_*
variables that this README documents and then calls it, so both ways are
equivalent and every variable below keeps working; a switch beats a variable of
the same name.

    NOCKPOOL_WALLET=<your payout address> NOCKPOOL_RIG=<name> ./run.sh

Pool endpoint: pool.nockforge.tech:27016, QUIC over UDP, outbound only --
nothing needs to be forwarded inbound. Your login is the payout address
itself: no account, no password, no API token. The miner never sees a private
key, holds none, and cannot move coins.

2. WHAT CHANGED WITH ANTHROPOS
------------------------------
Since block 147 500 the network runs ZK proof-version 5. A nonce is tested by
hashing proof object 0 alone (a Tip5 digest of the block commitment, the nonce
and the puzzle result); the full STARK proof is built only for a nonce that
meets the NETWORK target, i.e. for a block. This miner does exactly that: the
GPU grinds nonces, a share is the object-0 proof of a nonce that met the pool
target, and the Nock kernel shipped here (the stock Anthropos miner kernel)
proves a block-class hit in full before it is submitted.

Rates are therefore quoted in nonces per second, not in proofs per second.
0.3.x (proof-version 3) does not produce valid work any more.

3. POOL OR SOLO
---------------
Pool: PPLNS over the work of the last 8 network blocks, counted backwards from
the moment a block is found. Your share of that window is your share of the
block, minus the 2 % fee.

Solo: end the rig name with -solo (also "solo" or ".solo"), e.g.
NOCKPOOL_RIG=rig1-solo. The whole block reward is yours when you find one,
minus the same 2 % solo fee. Same endpoint, same miner, same payout path.

Payouts run once a day, at 20:00 UTC, and go straight to your address once
your balance reaches your threshold -- 100 NOCK by default, adjustable per
address at nockforge.tech/miner/<address>. One address, one mode per rig:
pool rigs and solo rigs can run under the same address at once.

4. WHAT YOU NEED
----------------
GPU     NVIDIA, Ampere or newer. Precompiled kernel images ship for compute
        capability 8.0, 8.6, 8.9, 9.0, 10.0 and 12.0 -- Ampere, Ada, Hopper,
        Blackwell; a card outside that list is refused at startup (the grind
        needs the int8 tensor-core instruction of sm_80+, so Turing is out). Measured
        only on the RTX 5090: 124.0 M nonces/s at a 540 W board limit and stock
        clocks (3-minute runs, 23.09.2026); other cards start but are untested
        and slower.
VRAM    Under 1 GB.
CPU     A few free cores for the block prover. A block-class hit is proven in
        about 0.2 s, most of it on the GPU (measured on an RTX 5090 with a
        6-core Ryzen 5 7500F); mining pauses for that moment.
RAM     4 GB host RAM. Under WSL2 that is RAM given to the guest.
Driver  NVIDIA R550 or newer (Blackwell cards: R570 or newer). No CUDA toolkit
        needed: libcuda.so.1 is the only
        NVIDIA library the miner loads.
OS      Linux x86_64, glibc 2.39 or newer (Ubuntu 24.04). Windows only through
        WSL2 on the Windows NVIDIA driver -- no Linux GPU driver inside WSL.

Several GPUs: one miner process drives one card, and run.sh starts one process
per card by itself when nvidia-smi lists more than one. Each card mines under
its own rig name (rig1 -> rig1-gpu0, rig1-gpu1, ...; a -solo suffix stays at
the end), reports its own model, and writes its own log next to run.sh. The
terminal follows all logs; Ctrl-C stops every card. NOCKPOOL_GPUS=0,2 limits
it to those indices, CUDA_VISIBLE_DEVICES=1 keeps the classic one-card run.

5. WHAT IT LOOKS LIKE WHEN IT WORKS
-----------------------------------
    quiver: authenticated, device accepted (linux / <your GPU>)
    job 1 commit a2a826916ed6d2e2 weight 4.356e8 nonces per share, 4.356e13 per block, epoch 0
    HIT: job 2 nonce[0]=11788940857570136741 share 745 bytes -> pool
    SHARE ACCEPTED: accepted
      LOCAL 124.01 M nonces/s since start • 1h ~123.95 M • 24h ~123.95 M • 3m20s
      WORKER       DEVICE              60 s   CLOCK   FAN   TEMP   POWER        EFF     SHARES  UP
      rig1         RTX 5090        123.95 M    2430   65%   68 C   540 W    230 k/W     70 / 0  3m20s

SHARE ACCEPTED is the only proof that you are earning. Under SHARES the table
shows accepted / rejected; a rejected count above 0 is a defect -- stop and
report it with the log. LOCAL is the average since start (and over the last
hour and day); the "60 s" column is the trailing minute, which is also what
the pool is told.

A hit that meets the network target prints HIT BLOCK-CLASS and goes to the
prover; "BLOCK proof ... -> pool" follows well under a second later. That is
rare and normal.

5a. THE CLOCK OFFSET (OFF BY DEFAULT)
-------------------------------------
The miner does not change your clocks. It only does so if you ask:

    ./nockforge --wallet <address> --clock-offset 100    # +100 MHz core
    ./nockforge --wallet <address> --clock-offset 0      # back to stock

Earlier versions raised the core clock on startup. That is over, and the
measurement behind the decision is worth repeating, because it is the opposite
of what one expects: on an RTX 4080 SUPER another miner does 44 M nonces/s at
2175 MHz and 139 W, while ours did 43 M nonces/s at 2400 MHz and 168 W. More
clock cost more power and delivered less work. The road to more nonces per
watt runs through the kernel, not through the clock.

If you do set an offset:

  * It needs root. Without it the miner says so in one line and runs at stock
    clocks. Nothing breaks.
  * An unstable clock does not have to crash -- it can simply compute wrong
    answers, and wrong answers earn nothing. The miner checks every hit
    against the CPU before anything is sent and lowers the offset by itself if
    the GPU disagrees: first disagreement one step down, second switches it
    off for the run, a rejected share switches it off at once. It never raises
    it.
  * It is device-wide and stays on the card until reboot. "--clock-offset 0"
    resets it. Do not use it on a laptop or on a machine whose GPU other
    people share.
  * On our own RTX 5090 the digest gates stayed green up to +400 MHz and +450
    crashed the card hard enough to need a reboot. That was one card, and it
    does not carry to yours.

Watch two things: a line starting with "!! HIT REFUSED" (our own check caught a
GPU error) and the rejected count under SHARES (the pool threw work away). Both
should stay 0.

6. CONFIGURATION
----------------
    NOCKPOOL_WALLET        (required)  your base58 payout address, and your login
    NOCKPOOL_RIG           [rig1]      worker label; -solo selects solo mode
    NOCKPOOL_GPUS          [all]       GPU indices to mine on, e.g. 0,2 -- one
                                       process per card, see section 4
    NOCKPOOL_SERVER        [pool.nockforge.tech:27016]  host:port of the pool
    NOCKPOOL_INSECURE      [0]         1 disables certificate checking
    ZKMINER_CLOCK_OFFSET   [off]       GPU core clock offset in MHz; "off"
                                       leaves the clock untouched, 0 resets it
                                       to stock -- see section 5a
    ZKMINER_V5_KERNEL      [miner.jam shipped here]  the Nock prover kernel
    ZKMINER_V5_COMPLETERS  [1]         booted prover kernels (CPU); 0 disables proving
    ZKMINER_GPU_MODEL      [detected]  reported to the pool, cosmetic
    RUST_LOG               [info]

Connect by NAME. The pool's certificate is issued for pool.nockforge.tech and
carries no IP SAN, so connecting by IP only works with NOCKPOOL_INSECURE=1 --
which turns certificate verification off entirely and is for testing only.

7. PACKAGE CONTENTS AND LICENCE
-------------------------------
    zkminer-miner     the miner (closed source; its own source is not published)
    miner.jam         the Nock kernel that proves a block-class hit
                      (assets/miner.jam of Nockchain 0.1.17, unchanged)
    nockforge         the simple entry point: ./nockforge --wallet <address>
    run.sh            launcher: checks the wallet, the pool name, the driver
    README.txt        this file
    SHA256SUMS        checksums of every other file (sha256sum -c SHA256SUMS)
    NOTICE            what third-party code is in the binary, on what terms
    THIRD-PARTY.txt   every linked package with version and licence
    LICENSE-MIT, LICENSE-APACHE, LICENSE-MPL-2.0   the texts NOTICE refers to

The Nockchain code inside the binary and the miner.jam kernel are
dual-licensed MIT OR Apache-2.0, which permits binary redistribution as long
as the licence text travels with it. One linked package is under MPL-2.0;
NOTICE names it and says where its source is. No package in the graph is
under GPL, LGPL or AGPL.

This package contains no wallet, no key and no token. If you ever find a key in
a mining package, from us or anyone else, do not run it. There is no warranty
of any kind, including for what the miner earns.
