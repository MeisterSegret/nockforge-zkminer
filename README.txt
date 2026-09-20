nockforge zkminer 0.6.2 -- GPU miner for Nockchain (proof-version 5, Anthropos)
================================================================================
Linux x86_64, NVIDIA.

1. QUICK START
--------------
    sha256sum nockforge-zkminer-0.6.2.tar.gz     # compare with the site
    tar xzf nockforge-zkminer-0.6.2.tar.gz && cd nockforge-zkminer-0.6.2
    ./nockforge --wallet <your payout address>

That is the whole setup. Two more switches cover almost every rig:

    ./nockforge --wallet <address> --device rig1        # name this rig in the pool
    ./nockforge --wallet <address> --device rig1 --gpus 0,2

    --device <name>    worker label shown in the pool (default: rig1). On a
                       multi-GPU box the miner appends "-gpu<i>" per card.
    --gpus <list>      which cards: "0", "0,2" or "all" (default: all).
    --clock-offset <n> GPU core clock offset in MHz (default: 100, see 5a)
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
        only on the RTX 5090 (115.8 M nonces/s at a 600 W board limit, 107.2 M
        at 540 W, sustained); other
        cards start but are untested and slower.
VRAM    Under 1 GB.
CPU     One free core for the block prover (~30 s per block-class hit).
RAM     4 GB host RAM. Under WSL2 that is RAM given to the guest.
Driver  NVIDIA R550 or newer (Blackwell cards: R570 or newer). No CUDA toolkit
        needed: libcuda.so.1 is the only
        NVIDIA library the miner loads.
OS      Linux x86_64, glibc 2.38 or newer (Ubuntu 24.04). Windows only through
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
    job 1 commit 17b1f84d1213f667 weight 2.083e8 nonces per share, 2.083e13 per block, epoch 0
    LOCAL 115751234 cand/s (115.75 M nonces/s) | 60s 115.75 M/s | GPU 70 C 600 W | shares 350 accepted 0 rejected | hits 350 | ...
    HIT: job 3 nonce[0]=13781368888098607096 share 745 bytes -> pool
    SHARE ACCEPTED: accepted

The last line is the only proof that you are earning. On the LOCAL line,
accepted must keep up with hits; REJECTED above 0 is a defect -- stop and
report it with the log. The cand/s figure is a running average since start;
"60s" is the trailing minute, which is also what the pool is told.

A hit that meets the network target prints HIT BLOCK-CLASS and goes to the
prover; "BLOCK proof ... -> pool" follows about 30 s later. That is rare and
normal.

5a. THE CLOCK OFFSET (ON BY DEFAULT, AND IT WATCHES ITSELF)
-----------------------------------------------------------
This version raises the GPU core clock by 100 MHz on startup, without being
asked, and prints one line about it:

    == clock offset +100 MHz on 0000:01:00.0 (was +0, now +100, SM 2640 MHz) ==

READ THE NEXT TWO PARAGRAPHS BEFORE YOU RUN THIS ON A CARD THAT IS NOT AN
RTX 5090.

Why: the rate of this miner is almost exactly 0.04475 M nonces/s per MHz of
core clock on the card we measured. Nothing else in the loop moves it as much.

WHAT WE ACTUALLY MEASURED, AND WHAT WE DID NOT
On ONE card -- our own RTX 5090, fans at 100 % -- the ladder was green against
the digest gates up to +400 (127.0 M/s at 2835 MHz), and +450 crashed the card
hard enough that the machine had to be rebooted. That is the whole of it.

We have never tested a GeForce 30-series or 40-series card, or any other
model. Published overclocking results for Ampere are far tighter than ours:
one RTX 3070 was stable at +80 and crashed at +100, and reviewers ran the 3080
at +25 and the 3090 at +45. Those are game-load results, which is not the same
thing as computing correctly.

That is why the default is 100 and not more. Our own figure -- **118.1 M
nonces/s at a 540 W board limit, held over 36 minutes with no rejected shares**
-- was measured on our RTX 5090 with the offset raised to 250, which is what we
run on our own rigs. The shipped default is deliberately lower, because it has
to be safe on cards we have never seen. Raise it with "--clock-offset" if you
know yours, and start from "off" if you do not.

AN OFFSET IS NOT A CLOCK
On our own card a requested +250 turned into roughly +100 MHz of actual SM
clock -- the rest was eaten by the power limit. What your card does with an
offset is decided by GPU Boost from the power limit and the temperature. Do
not compute an expected rate from the offset; read the SM figure the miner
prints instead. The 0.04475 per-MHz factor is an RTX 5090 number and does not
carry to other cards.

THE MINER LOWERS IT BY ITSELF
An unstable core clock does not necessarily crash -- it computes wrong
answers, which earn nothing. The miner checks every hit on the CPU before
anything is sent, so it notices this on its own, roughly once every few
seconds, without waiting for the pool:

    first disagreement    -> offset drops one step (30 MHz)
    second disagreement   -> offset goes to 0 for the rest of the run
    a REJECTED share      -> offset goes to 0 immediately

It never raises the offset by itself. Watch two figures on the LOCAL line:
"divergence" (our own check caught a GPU error) and "REJECTED" (the pool threw
work away). Both should stay at 0.

THE OFFSET OUTLIVES THE MINER
Once set, the offset stays on the card until the machine reboots or the driver
is reloaded -- stopping the miner does not by itself put it back.
"--clock-offset 0" resets it. Keep that in mind on a machine you share or rent
out: the offset is device-wide and the next workload on that card inherits it.

THE REST
  * The driver only accepts this from root. Without root the miner prints
    "NOT applied: ... (no permission)" and runs at stock clocks. Nothing
    breaks; it is simply not faster.
  * It needs driver R525 or newer. Older drivers have no such call.
  * Do not use it on a laptop GPU, or on a machine whose GPU other people
    share: the offset is device-wide and affects every process on that card.

    ./nockforge --wallet <address> --clock-offset off    # do not touch clocks
    ./nockforge --wallet <address> --clock-offset 0      # back to stock
    ./nockforge --wallet <address> --clock-offset <n>    # your own value

To find your own value, go up in small steps, leave each step running long
enough to be sure, and stay two steps below the first sign of trouble.

On a multi-GPU box each process sets the offset on its own card; the card is
identified by PCI address, not by index, so a remapped CUDA order cannot make
a process overclock a card it is not using. If you run several miner processes
on ONE card (CUDA MPS), set --clock-offset off on all but one -- otherwise they
fight over the same setting.

The rates quoted in section 4 were measured WITHOUT any offset. They are the
floor, not the ceiling.

6. CONFIGURATION
----------------
    NOCKPOOL_WALLET        (required)  your base58 payout address, and your login
    NOCKPOOL_RIG           [rig1]      worker label; -solo selects solo mode
    NOCKPOOL_GPUS          [all]       GPU indices to mine on, e.g. 0,2 -- one
                                       process per card, see section 4
    NOCKPOOL_SERVER        [pool.nockforge.tech:27016]  host:port of the pool
    NOCKPOOL_INSECURE      [0]         1 disables certificate checking
    ZKMINER_CLOCK_OFFSET   [100]       GPU core clock offset in MHz; "off"
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
