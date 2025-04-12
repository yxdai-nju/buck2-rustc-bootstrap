import argparse
import os
from pathlib import Path
from typing import NamedTuple


class Args(NamedTuple):
    dist: Path
    relative: Path
    symlink: Path


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--dist", type=Path)
    parser.add_argument("--relative", type=Path)
    parser.add_argument("--symlink", type=Path)
    args = Args(**vars(parser.parse_args()))

    toplevel = os.listdir(args.dist)
    if len(toplevel) != 1:
        raise RuntimeError(
            "unexpected top-level directory entries: {}".format(toplevel),
        )

    components = args.dist / toplevel[0] / "components"
    with open(components) as f:
        component = f.read().strip()

    src = args.relative / toplevel[0] / component
    os.symlink(src, args.symlink)
