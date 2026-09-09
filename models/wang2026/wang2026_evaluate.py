"""Wang2026 (ei_yang) azimuth evaluation for MATLAB pyrunfile.

Mirrors ei_yang/model_prediction/model_prediction.ipynb:
  binaural signal -> cochleagram -> EI pattern -> RMS -> Keras -> degrees.

Inputs (MATLAB globals via pyrunfile, or defaults for standalone use):
  binaural_signal  ndarray (nSignals, nSamples, 2) or (nSamples, 2)
  signal_sr        int, sampling rate in Hz
  model_filename   optional str under ei_yang/IEEE25_models/ (default P3.keras)
  ei_yang_root     optional str, path to the ei_yang repository checkout.
                   Falls back to the EI_YANG_ROOT environment variable.

Exports:
  globals()["result"] = {"azimuth_deg": [...], "model_filename": "..."}
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

import numpy as np
import tensorflow as tf
from brian2 import Hz
from brian2hears import Sound
from tensorflow.keras.models import load_model

DEFAULT_MODEL_FILENAME = "P3.keras"  # under ei_yang/IEEE25_models/

# Cochleagram parameters (notebook)
DOWNSAMPLE_FS = 4000
DOWNSAMPLE = True
N_C_FREQ = 31
MAX_FREQ = 16000
MIN_FREQ = 125
BANDPASS_CUTOFFS = [1000, 4000]
LOWPASS_CUTOFF = 1000

# EI pattern parameters (notebook)
INTERNAL_DELAY = 0.005
INTERNAL_INTENSITY = 10
NTAP_TAU = 24
NTAP_ALPHA = 12
TAUS = np.linspace(
    -INTERNAL_DELAY * DOWNSAMPLE_FS, INTERNAL_DELAY * DOWNSAMPLE_FS, NTAP_TAU
)
ALPHAS = np.linspace(-INTERNAL_INTENSITY, INTERNAL_INTENSITY, NTAP_ALPHA)
C_SMOOTH = int(round(6 * 0.03 * DOWNSAMPLE_FS))


def scaled_tanh(x):
    """Custom activation that scales tanh to ±π."""
    pi_constant = tf.cast(tf.constant(np.pi), dtype=x.dtype)
    return pi_constant * tf.math.tanh(x)


def retanh(x):
    return tf.where(x > 0, tf.math.tanh(x), tf.zeros_like(x))


def _resolve_ei_yang_root(explicit_root=None) -> Path:
    """Locate the ei_yang checkout: explicit argument, else EI_YANG_ROOT env."""
    candidate = str(explicit_root).strip() if explicit_root is not None else ""
    if not candidate:
        candidate = os.environ.get("EI_YANG_ROOT", "").strip()
    if not candidate:
        raise FileNotFoundError(
            "ei_yang root not given. Pass `ei_yang_root` (MATLAB: "
            "local_paths().ei_yang_dir) or set the EI_YANG_ROOT environment variable."
        )
    root = Path(candidate).expanduser().resolve()
    if not root.is_dir():
        raise FileNotFoundError(
            f"ei_yang root not found: {root}. Check local_paths.m / EI_YANG_ROOT."
        )
    return root


def _as_numpy(x) -> np.ndarray:
    if hasattr(x, "tolist") and not isinstance(x, np.ndarray):
        # MATLAB pyarray / nested sequences
        try:
            return np.asarray(x, dtype=np.float64)
        except (TypeError, ValueError):
            return np.array(x, dtype=np.float64)
    return np.asarray(x, dtype=np.float64)


def _normalize_batch(binaural_signal: np.ndarray) -> np.ndarray:
    """Return array shaped (nSignals, nSamples, 2)."""
    x = _as_numpy(binaural_signal)
    if x.ndim == 2:
        if x.shape[1] != 2:
            raise ValueError(
                f"Expected (nSamples, 2) or (nSignals, nSamples, 2); got {x.shape}"
            )
        return x[np.newaxis, ...]
    if x.ndim == 3:
        if x.shape[-1] != 2:
            raise ValueError(
                f"Expected last dim nChannels=2; got shape {x.shape}"
            )
        return x
    raise ValueError(f"Unsupported binaural_signal ndim={x.ndim}, shape={x.shape}")


def _load_model(model_path: Path):
    return load_model(
        model_path,
        safe_mode=False,
        compile=False,
        custom_objects={"Custom>scaled_tanh": scaled_tanh, "Custom>retanh": retanh},
    )


def estimate_azimuth_deg(
    binaural_signal,
    signal_sr: int,
    model_filename: str = DEFAULT_MODEL_FILENAME,
    ei_yang_root: Path | None = None,
) -> dict:
    """Run notebook-equivalent pipeline for one or more binaural signals."""
    root = _resolve_ei_yang_root(ei_yang_root)
    if str(root) not in sys.path:
        sys.path.insert(0, str(root))

    from cochleagram_func import human_cochleagram
    from ei_pattern_func import compute_eipattern

    model_filename = str(model_filename)
    model_path = root / "IEEE25_models" / model_filename
    if not model_path.is_file():
        raise FileNotFoundError(f"Keras model not found: {model_path}")

    batch = _normalize_batch(binaural_signal)
    n_signals = batch.shape[0]
    fs = int(signal_sr)

    model = _load_model(model_path)
    azimuth_deg = np.empty(n_signals, dtype=np.float64)

    for i in range(n_signals):
        signal = batch[i]
        # Samplerate is passed explicitly so filterbanks match stimulus fs
        # (notebook omits this for fixed 48 kHz example WAVs).
        sound = Sound(signal, samplerate=fs * Hz)
        cochleagram = human_cochleagram(
            sound,
            N_C_FREQ,
            MIN_FREQ,
            MAX_FREQ,
            BANDPASS_CUTOFFS,
            LOWPASS_CUTOFF,
            fs,
            DOWNSAMPLE_FS,
            downsample=DOWNSAMPLE,
        )
        ei = compute_eipattern(cochleagram, DOWNSAMPLE_FS, TAUS, ALPHAS, C_SMOOTH)
        ei_rms = np.sqrt(np.mean(ei**2, axis=0))
        x = np.expand_dims(ei_rms.astype(np.float32, copy=False), axis=0)
        pred_rad = model.predict(x, verbose=0)
        azimuth_deg[i] = float(np.degrees(pred_rad[0, 0]))

    return {
        "azimuth_deg": azimuth_deg.tolist(),
        "model_filename": model_filename,
    }


def main():
    if "binaural_signal" not in globals():
        raise ValueError(
            "Provide input via MATLAB global `binaural_signal` "
            "(and optional `signal_sr`, `model_filename`)."
        )

    signal = globals()["binaural_signal"]
    signal_sr = int(globals().get("signal_sr", 48000))
    model_filename = globals().get("model_filename", DEFAULT_MODEL_FILENAME)
    if hasattr(model_filename, "tolist"):
        # MATLAB string / char may arrive as nested list
        model_filename = str(np.asarray(model_filename).item())
    else:
        model_filename = str(model_filename)
    ei_yang_root = globals().get("ei_yang_root", None)
    if ei_yang_root is not None and hasattr(ei_yang_root, "tolist"):
        ei_yang_root = str(np.asarray(ei_yang_root).item())

    print(
        f"[wang2026_evaluate] n_signals batch, "
        f"sr={signal_sr}, model={model_filename}"
    )
    result = estimate_azimuth_deg(
        binaural_signal=signal,
        signal_sr=signal_sr,
        model_filename=model_filename,
        ei_yang_root=ei_yang_root,
    )
    globals()["result"] = result
    print(
        f"[wang2026_evaluate] done: {len(result['azimuth_deg'])} angles, "
        f"model={result['model_filename']}"
    )


if __name__ == "__main__":
    main()
