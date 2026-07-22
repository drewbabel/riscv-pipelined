#!/usr/bin/env python3
# Lockstep co-sim of the pipelined core against Spike
# python3 tests/cosim.py <prog> | --rand [count] [seed0]

import os
import random
import re
import subprocess
import sys

BASE = 0x8000_0000  # Spike DRAM base
DEPTH = 64
MASK32 = 0xFFFF_FFFF
ABS_PC_OPS = {0x17, 0x6F, 0x67}  # auipc jal jalr
STORE_WIDTH = {0: 1, 1: 2, 2: 4}  # store funct3 to byte count

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD = os.path.join(ROOT, "build")
PKGS = ["alu_pkg.sv", "csr_pkg.sv", "opcode_pkg.sv", "muldiv_pkg.sv"]
RTL = [os.path.join(ROOT, "rtl", p) for p in PKGS] + [
    os.path.join(ROOT, "rtl", f)
    for f in sorted(os.listdir(os.path.join(ROOT, "rtl")))
    if f.endswith(".sv") and f not in PKGS
]

RVGCC = "riscv64-elf-gcc"
GCC_COMMON = ["-march=rv32im", "-mabi=ilp32", "-nostdlib", "-nostartfiles", "-Os"]
SIM = os.path.join(BUILD, "cosim_sim")


def sh(cmd):
    subprocess.run(cmd, check=True, cwd=ROOT)


# Compile the monitor
def compile_monitor():
    os.makedirs(BUILD, exist_ok=True)
    sh(["iverilog", "-g2012", "-DRISCV_FORMAL", "-s", "cosim", "-o", SIM, *RTL,
        os.path.join("tb", "cosim.sv")])


# dut hex plus spike elf
def build_images(src, hexout, spike_elf):
    dut_elf = os.path.join(BUILD, "dut.elf")
    sh([RVGCC, *GCC_COMMON, "-T", "tests/link.ld", "-o", dut_elf, src])
    sh(["riscv64-elf-objcopy", "-O", "verilog", "--verilog-data-width=4", dut_elf, hexout])
    sh([RVGCC, *GCC_COMMON, "-T", "tests/link_spike.ld", "-o", spike_elf, src])


# dut commit trace
def run_dut(dut_hex):
    out = subprocess.run(["vvp", SIM, f"+hex={dut_hex}", "+n=8000"],
                         cwd=ROOT, capture_output=True, text=True).stdout
    trace = []
    for line in out.splitlines():
        m = re.match(r"COMMIT ([0-9a-f]+) (\d+) ([0-9a-f]+) (\d+) ([0-9a-f]+) ([0-9a-f]+) ([0-9a-f]+)", line)
        if not m:
            continue
        pc, rd, val, mw, maddr, wstrb, sdata = m.groups()
        rd_i = int(rd)
        val_i = (int(val, 16) & MASK32) if rd_i else 0  # x0 carries no value
        store = None
        if mw == "1":  # written bytes, one entry per strobed lane
            ws, sd = int(wstrb, 16), int(sdata, 16)
            widx = (int(maddr, 16) >> 2) & (DEPTH - 1)
            store = (widx, tuple((i, (sd >> (8 * i)) & 0xFF) for i in range(4) if ws & (1 << i)))
        trace.append((int(pc, 16), rd_i, val_i, store))
    return trace


SPIKE_RE = re.compile(r"core\s+\d+:\s+\d+\s+0x([0-9a-f]+)\s+\(0x([0-9a-f]+)\)(.*)")  # commit line


# Golden spike trace
def run_spike(spike_elf, n):
    maxlines = 4 * n + 200  # head ends the park-loop
    cmd = f"spike --isa=rv32im --pc={hex(BASE)} -l --log-commits {spike_elf} 2>&1 | head -n {maxlines}"
    out = subprocess.run(cmd, shell=True, cwd=ROOT, capture_output=True, text=True).stdout
    trace = []
    for line in out.splitlines():
        m = SPIKE_RE.match(line)
        if not m:
            continue
        pc_raw, instr_hex, tail = m.groups()
        insn = int(instr_hex, 16)
        opcode = insn & 0x7F
        rd, val = 0, 0
        rm = re.search(r"(?:^|\s)x(\d+)\s+0x([0-9a-f]+)", tail)  # register write
        if rm:
            rd = int(rm.group(1))
            val = int(rm.group(2), 16) & MASK32
            if opcode in ABS_PC_OPS and rd != 0:
                val = (val - BASE) & MASK32  # to dut space
        store = None
        sm = re.search(r"mem\s+0x([0-9a-f]+)\s+0x([0-9a-f]+)", tail)  # store logs addr + value
        if sm:
            saddr, sval = int(sm.group(1), 16), int(sm.group(2), 16)
            width = STORE_WIDTH[(insn >> 12) & 0x7]  # sb=1 sh=2 sw=4
            off = saddr & 0x3
            widx = (saddr >> 2) & (DEPTH - 1)
            store = (widx, tuple((off + k, (sval >> (8 * k)) & 0xFF) for k in range(width)))
        pc = (int(pc_raw, 16) - BASE) & MASK32  # to dut space
        trace.append((pc, rd if rd != 0 else 0, val, store))
        if len(trace) >= n:
            break
    return trace


def fmt(rec):
    pc, rd, val, store = rec
    parts = [f"pc={pc:08x}", f"x{rd}={val:08x}" if rd else "x0"]
    if store is not None:
        widx, bs = store
        parts.append(f"mem[w{widx}] " + " ".join(f"b{i}={b:02x}" for i, b in bs))
    return "  ".join(parts)


# First mismatch wins
def compare(dut, spike):
    n = min(len(dut), len(spike))
    for i in range(n):
        if dut[i] != spike[i]:
            return False, f"instr {i}\n  DUT   {fmt(dut[i])}\n  Spike {fmt(spike[i])}"
    if len(dut) != len(spike):
        return False, f"length DUT {len(dut)} Spike {len(spike)}"
    return True, n


# Randomized program generation

R_OPS = ["add", "sub", "sll", "slt", "sltu", "xor", "srl", "sra", "or", "and"]
I_OPS = ["addi", "slti", "sltiu", "xori", "ori", "andi"]
SH_OPS = ["slli", "srli", "srai"]
BR_OPS = ["beq", "bne", "blt", "bge", "bltu", "bgeu"]
MUL_OPS = ["mul", "mulh", "mulhsu", "mulhu"]
DIV_OPS = ["div", "divu", "rem", "remu"]
BASE_REG = 3  # data pointer
DSTS = [r for r in range(1, 32) if r != BASE_REG]


# Program for one seed
def gen(seed):
    rng = random.Random(seed)
    mode = "linear" if seed % 2 == 0 else "control"
    n = rng.randint(24, 50)
    written = set()
    body = []

    def rd():
        return rng.choice(DSTS)

    def rs():
        return rng.randint(0, 31)

    for i in range(n):
        # Linear loads, no base-relative ops
        mem_st = ["stb", "sth"] if written else []
        mem_ld = ["ldb", "ldh"] if written else []
        if mode == "linear":
            pool = ["r", "i", "sh", "lui", "mul", "div", "sw"] + (["lw"] if written else []) + mem_st + mem_ld
        else:
            pool = ["r", "i", "sh", "lui", "mul", "div", "sw", "branch", "jal"] + mem_st
        kind = rng.choice(pool)

        match kind:
            case "r":
                body.append(f"{rng.choice(R_OPS)} x{rd()}, x{rs()}, x{rs()}")
            case "i":
                body.append(f"{rng.choice(I_OPS)} x{rd()}, x{rs()}, {rng.randint(-2048, 2047)}")
            case "sh":
                body.append(f"{rng.choice(SH_OPS)} x{rd()}, x{rs()}, {rng.randint(0, 31)}")
            case "lui":
                body.append(f"lui x{rd()}, {rng.randint(0, 0xFFFFF)}")
            case "mul":
                body.append(f"{rng.choice(MUL_OPS)} x{rd()}, x{rs()}, x{rs()}")
            case "div":
                body.append(f"{rng.choice(DIV_OPS)} x{rd()}, x{rs()}, x{rs()}")
            case "sw":
                word = rng.randint(0, DEPTH - 1)
                written.add(word)
                body.append(f"sw x{rs()}, {word * 4}(x{BASE_REG})")
            case "lw":
                word = rng.choice(sorted(written))
                body.append(f"lw x{rd()}, {word * 4}(x{BASE_REG})")
            case "stb":
                word = rng.choice(sorted(written))
                body.append(f"sb x{rs()}, {word * 4 + rng.randint(0, 3)}(x{BASE_REG})")
            case "sth":
                word = rng.choice(sorted(written))
                body.append(f"sh x{rs()}, {word * 4 + rng.choice([0, 2])}(x{BASE_REG})")
            case "ldb":
                word = rng.choice(sorted(written))
                body.append(f"{rng.choice(['lb', 'lbu'])} x{rd()}, {word * 4 + rng.randint(0, 3)}(x{BASE_REG})")
            case "ldh":
                word = rng.choice(sorted(written))
                body.append(f"{rng.choice(['lh', 'lhu'])} x{rd()}, {word * 4 + rng.choice([0, 2])}(x{BASE_REG})")
            case "branch":
                tgt = rng.choice([f"L{k}" for k in range(i + 1, n)] + ["Ldone"])
                body.append(f"{rng.choice(BR_OPS)} x{rs()}, x{rs()}, {tgt}")
            case "jal":
                tgt = rng.choice([f"L{k}" for k in range(i + 1, n)] + ["Ldone"])
                body.append(f"jal x0, {tgt}")

    # Base 0x80008000 clears the code in Spike
    lines = ["        .section .text", "        .globl _start", "_start:",
             f"        lui x{BASE_REG}, 0x80008"]
    for i, insn in enumerate(body):
        lines.append(f"L{i}: {insn}")
    lines.append("Ldone: beq x0, x0, Ldone")  # park sentinel
    return "\n".join(lines) + "\n", mode


# Build run compare
def run_one(src):
    dut_hex = os.path.join(BUILD, "prog.hex")
    spike_elf = os.path.join(BUILD, "prog_spike.elf")
    build_images(src, dut_hex, spike_elf)
    dut = run_dut(dut_hex)
    spike = run_spike(spike_elf, len(dut))
    return compare(dut, spike)


def main():
    if len(sys.argv) >= 2 and sys.argv[1] == "--rand":  # random regression
        count = int(sys.argv[2]) if len(sys.argv) >= 3 else 200
        seed0 = int(sys.argv[3]) if len(sys.argv) >= 4 else 0
        compile_monitor()
        total = 0
        for seed in range(seed0, seed0 + count):
            asm, mode = gen(seed)
            src = os.path.join(BUILD, "rand.s")
            with open(src, "w") as f:
                f.write(asm)
            ok, detail = run_one(src)
            if not ok:
                fail = os.path.join(BUILD, f"fail_{seed}.s")  # reproducible seed
                with open(fail, "w") as f:
                    f.write(asm)
                print(f"FAIL seed={seed} mode={mode}\n{detail}\nprogram saved to {fail}")
                sys.exit(1)
            total += detail
        print(f"RANDOM PASS: {count} programs, {total} instructions matched Spike")
        return

    if len(sys.argv) != 2:
        sys.exit("usage: python3 tests/cosim.py <prog> | --rand [count] [seed0]")
    prog = sys.argv[1]  # single program, assembly or C
    compile_monitor()
    src_c = os.path.join("tests", f"{prog}.c")
    src = src_c if os.path.exists(src_c) else os.path.join("tests", f"{prog}.s")
    dut_hex = os.path.join("tests", f"{prog}.hex")
    spike_elf = os.path.join(BUILD, f"{prog}_spike.elf")
    build_images(src, dut_hex, spike_elf)
    dut = run_dut(dut_hex)
    spike = run_spike(spike_elf, len(dut))
    ok, detail = compare(dut, spike)
    if not ok:
        print(f"DIVERGENCE {detail}")
        sys.exit(1)
    print(f"LOCKSTEP PASS: {detail} instructions match Spike ({prog})")


if __name__ == "__main__":
    main()
