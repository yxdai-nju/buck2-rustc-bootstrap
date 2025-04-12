import argparse
import os
import subprocess
import sys
from pathlib import Path
from typing import List, NamedTuple


class Args(NamedTuple):
    dist: Path
    exe: str
    env: List[str]
    rest: List[str]


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--dist", type=Path)
    parser.add_argument("--exe", type=str)
    parser.add_argument("--env", action="append", default=[])
    parser.add_argument("rest", nargs="*", type=str)
    args = Args(**vars(parser.parse_args()))

    env = os.environ.copy()
    for entry in args.env:
        k, v = entry.split("=", 1)
        env[k] = v

    toplevel = os.listdir(args.dist)
    if len(toplevel) != 1:
        raise RuntimeError(
            "unexpected top-level directory entries: {}".format(toplevel),
        )

    components = args.dist / toplevel[0] / "components"
    with open(components) as f:
        component = f.read().strip()

    exe = args.dist / toplevel[0] / component / "bin" / args.exe
    res = subprocess.run([exe] + args.rest, env=env)
    sys.exit(res.returncode)
