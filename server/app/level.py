"""
The vectors we store are either backbones, level 0, or level 1
"""

import enum


class VectorLevel(enum.Enum):
    BACKBONE = enum.auto()
    LEVEL0 = enum.auto()
    LEVEL1 = enum.auto()
