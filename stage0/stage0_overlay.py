import argparse
import os
import shutil
from pathlib import Path
from typing import NamedTuple


class Args(NamedTuple):
    dist: Path
    exe: str
    libdir: Path
    overlay: Path


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--dist", type=Path)
    parser.add_argument("--exe", type=str)
    parser.add_argument("--libdir", type=Path)
    parser.add_argument("--overlay", type=Path)
    args = Args(**vars(parser.parse_args()))

    toplevel = os.listdir(args.dist)
    if len(toplevel) != 1:
        raise RuntimeError(
            "unexpected top-level directory entries: {}".format(toplevel),
        )

    components = args.dist / toplevel[0] / "components"
    with open(components) as f:
        component = f.read().strip()

    # Copy binary
    os.mkdir(args.overlay)
    os.mkdir(args.overlay / "bin")
    shutil.copy2(
        args.dist / toplevel[0] / component / "bin" / args.exe,
        args.overlay / "bin",
    )

    toplevel = os.listdir(args.overlay / args.libdir)
    if len(toplevel) != 1:
        raise RuntimeError(
            "unexpected top-level directory entries: {}".format(toplevel),
        )

    components = args.overlay / args.libdir / toplevel[0] / "components"
    with open(components) as f:
        component = f.read().strip()

    # Symlink lib dir
    os.symlink(
        args.libdir / toplevel[0] / component / "lib",
        args.overlay / "lib",
    )
