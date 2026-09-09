#!/usr/bin/env python3
"""Run WaveLoc inference for MATLAB-exported binaural batches."""

import argparse
import configparser
import json
import os
import sys

import numpy as np
from scipy.io import loadmat
from scipy.signal import resample_poly

from WaveLoc import WaveLoc

FRAME = 320  # 20 ms at 16 kHz
HOP = 160    # 10 ms at 16 kHz
N_CLASSES = 37
CLASS_ANGLES = (np.arange(N_CLASSES, dtype=np.float32) - 18.0) * 5.0
UNIFORM_ENTROPY = float(-np.sum((1.0 / N_CLASSES) * np.log(1.0 / N_CLASSES)))


def _build_frames(signal_lr):
    if signal_lr.ndim != 2 or signal_lr.shape[1] != 2:
        raise ValueError("Each signal must have shape (n_samples, 2)")
    if signal_lr.shape[0] < FRAME:
        raise ValueError(
            f"Signal length ({signal_lr.shape[0]}) is shorter than FRAME ({FRAME})."
        )
    n_frames = (signal_lr.shape[0] - FRAME) // HOP + 1
    return np.stack(
        [signal_lr[i * HOP:i * HOP + FRAME] for i in range(n_frames)],
        axis=0,
    )[..., None]


def _frame_rms(frames):
    return np.sqrt(np.mean(np.square(frames), axis=(1, 2, 3)))


def _active_frame_mask(frames, threshold_db):
    rms = _frame_rms(frames)
    max_rms = float(np.max(rms))
    if max_rms <= 0.0:
        return np.ones(frames.shape[0], dtype=bool)
    threshold = max_rms * (10.0 ** (threshold_db / 20.0))
    return rms >= threshold


def _prob_entropy(probs):
    clipped = np.clip(probs, 1e-12, 1.0)
    return float(-np.sum(clipped * np.log(clipped)))


def _predict_chunked(probs_per_frame, chunk_size):
    """Match WaveLoc paper / evaluate_chunk_rmse: argmax over chunk means."""
    n_frames = probs_per_frame.shape[0]
    if n_frames == 0:
        raise ValueError("No frames available for WaveLoc inference.")

    if n_frames < chunk_size:
        mean_probs = probs_per_frame.mean(axis=0)
        cls = int(np.argmax(mean_probs))
        return cls, mean_probs, 0

    chunk_classes = []
    for start in range(0, n_frames - chunk_size + 1):
        chunk_probs = probs_per_frame[start:start + chunk_size].mean(axis=0)
        chunk_classes.append(int(np.argmax(chunk_probs)))

    cls = int(np.median(chunk_classes))
    mean_probs = probs_per_frame.mean(axis=0)
    return cls, mean_probs, len(chunk_classes)


def _prepare_batch(input_mat_path):
    mat = loadmat(input_mat_path)
    if "binaural_signal" not in mat:
        raise ValueError("Input MAT must contain variable 'binaural_signal'.")
    if "signal_sr" not in mat:
        raise ValueError("Input MAT must contain variable 'signal_sr'.")

    batch = np.asarray(mat["binaural_signal"], dtype=np.float32)
    if batch.ndim != 3 or batch.shape[2] != 2:
        raise ValueError(
            "Expected binaural_signal shape (n_signals, n_samples, 2)."
        )

    signal_sr = int(np.asarray(mat["signal_sr"]).squeeze())
    return batch, signal_sr


def _resample_batch(batch, input_sr, target_sr):
    if input_sr == target_sr:
        return batch
    if input_sr <= 0 or target_sr <= 0:
        raise ValueError("Sampling rates must be positive.")
    return resample_poly(batch, up=target_sr, down=input_sr, axis=1).astype(np.float32)


def run_waveloc_batch(
    input_mat,
    output_json,
    model_dir,
    chunk_size=25,
    energy_threshold_db=-40.0,
):
    batch, signal_sr = _prepare_batch(input_mat)

    config_path = os.path.join(model_dir, "config.cfg")
    if not os.path.isfile(config_path):
        raise FileNotFoundError(f"WaveLoc config not found: {config_path}")

    config = configparser.ConfigParser()
    config.read(config_path)
    target_fs = config.getint("model", "fs")

    batch = _resample_batch(batch, signal_sr, target_fs)

    model = WaveLoc(None, config_path)
    model.load_model(model_dir)

    argmax_azimuth_deg = []
    expected_azimuth_deg = []
    predicted_class_index = []
    n_frames_list = []
    n_active_frames_list = []
    n_chunks_list = []
    max_prob_list = []
    prob_entropy_list = []

    for idx in range(batch.shape[0]):
        frames = _build_frames(batch[idx])
        active_mask = _active_frame_mask(frames, energy_threshold_db)
        active_frames = frames[active_mask]
        if active_frames.shape[0] == 0:
            active_frames = frames

        probs_per_frame = np.asarray(model.predict(active_frames), dtype=np.float32)
        if probs_per_frame.ndim != 2 or probs_per_frame.shape[1] != N_CLASSES:
            raise ValueError("WaveLoc model.predict output has unexpected shape.")

        cls, mean_probs, n_chunks = _predict_chunked(probs_per_frame, chunk_size)
        max_prob = float(np.max(mean_probs))
        entropy = _prob_entropy(mean_probs)

        argmax_azimuth_deg.append(float((cls - 18) * 5))
        expected_azimuth_deg.append(float(np.sum(mean_probs * CLASS_ANGLES)))
        predicted_class_index.append(cls)
        n_frames_list.append(int(frames.shape[0]))
        n_active_frames_list.append(int(active_frames.shape[0]))
        n_chunks_list.append(int(n_chunks))
        max_prob_list.append(max_prob)
        prob_entropy_list.append(entropy)

    payload = {
        "argmax_azimuth_deg": argmax_azimuth_deg,
        "expected_azimuth_deg": expected_azimuth_deg,
        "predicted_class_index": predicted_class_index,
        "signal_sr_input": signal_sr,
        "signal_sr_model": target_fs,
        "chunk_size": int(chunk_size),
        "energy_threshold_db": float(energy_threshold_db),
        "n_frames": n_frames_list,
        "n_active_frames": n_active_frames_list,
        "n_chunks": n_chunks_list,
        "max_prob": max_prob_list,
        "prob_entropy": prob_entropy_list,
        "uniform_entropy": UNIFORM_ENTROPY,
    }
    with open(output_json, "w", encoding="utf-8") as f:
        json.dump(payload, f)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input_mat", required=True)
    parser.add_argument("--output_json", required=True)
    parser.add_argument("--model_dir", required=True)
    parser.add_argument("--chunk_size", type=int, default=25)
    parser.add_argument("--energy_threshold_db", type=float, default=-40.0)
    args = parser.parse_args()

    if args.chunk_size < 1:
        raise ValueError("chunk_size must be >= 1.")

    try:
        run_waveloc_batch(
            args.input_mat,
            args.output_json,
            args.model_dir,
            chunk_size=args.chunk_size,
            energy_threshold_db=args.energy_threshold_db,
        )
    except Exception as exc:  # pragma: no cover
        print(f"WaveLoc batch inference failed: {exc}", file=sys.stderr)
        raise


if __name__ == "__main__":
    main()
