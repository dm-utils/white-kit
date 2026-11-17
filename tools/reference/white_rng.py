#!/usr/bin/env python3
"""Independent reference of WhiteSeed and WhiteRng (docs/design.md 5.3, 5.4).

Prints the same lines as tools/rng_vectors.gd; CI compares both.
"""

M = 0xFFFFFFFF
SEEDS = [0, 1, -1, None]  # None = fnv1a64("white-kit")
TEXTS = ["", "a", "foobar", "white-shift|2026-11-17|2", "ë€\U0001d11e"]


def fnv1a64(text):
    h = 0xCBF29CE484222325
    for b in text.encode("utf-8"):
        h = ((h ^ b) * 0x100000001B3) % (1 << 64)
    return h


def to_signed(v):
    return v - (1 << 64) if v >= (1 << 63) else v


def rotl(x, k):
    return ((x << k) | (x >> (32 - k))) & M


def fmix(h):
    h ^= h >> 16
    h = (h * 0x85EBCA6B) & M
    h ^= h >> 13
    h = (h * 0xC2B2AE35) & M
    h ^= h >> 16
    return h


class Rng:
    def __init__(self, seed):
        u = seed % (1 << 64)
        lo, hi = u & M, u >> 32
        k = fmix(hi ^ 0x85EBCA6B)
        w = lo
        self.s = []
        for _ in range(4):
            w = (w + 0x9E3779B9) & M
            self.s.append(fmix(w ^ k))
        if not any(self.s):
            self.s[0] = 1

    def u32(self):
        s = self.s
        result = (rotl((s[1] * 5) & M, 7) * 9) & M
        t = (s[1] << 9) & M
        s[2] ^= s[0]
        s[3] ^= s[1]
        s[1] ^= s[2]
        s[0] ^= s[3]
        s[2] ^= t
        s[3] = rotl(s[3], 11)
        return result

    def range_int(self, lo, hi):
        n = hi - lo + 1
        limit = (1 << 32) - ((1 << 32) % n)
        r = self.u32()
        while r >= limit:
            r = self.u32()
        return lo + r % n


def main():
    for t in TEXTS:
        print("fnv %s %016x" % (t.encode("unicode_escape").decode(), fnv1a64(t)))
    for seed in SEEDS:
        if seed is None:
            seed = to_signed(fnv1a64("white-kit"))
        r = Rng(seed)
        print("seed %d" % seed)
        print("state " + " ".join(str(x) for x in r.s))
        print("u32 " + " ".join(str(r.u32()) for _ in range(8)))
        print("int " + " ".join(str(r.range_int(0, 6)) for _ in range(8)))
        print("float " + " ".join(str(r.u32()) for _ in range(4)))


main()
