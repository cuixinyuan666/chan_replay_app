from __future__ import annotations

# Compatibility entrypoint kept for existing imports in backend.app.main.
# The actual implementation lives in a_rhythm_overlay_trainer so the trainer
# parity port can evolve independently from the previous lightweight overlay.
from .a_rhythm_overlay_trainer import (  # noqa: F401
    RHYTHM_CALC_MODE_NORMAL,
    RHYTHM_CALC_MODE_STRICT_1382,
    RHYTHM_CALC_MODE_TRANSITION,
    RHYTHM_CALC_MODES,
    RHYTHM_RATIO,
    with_level_rhythm_overlay,
    with_multilevel_rhythm_overlay,
)
