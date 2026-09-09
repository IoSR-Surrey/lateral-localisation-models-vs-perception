#!/usr/bin/env python3

import os
import sys
import numpy as np
import scipy.io as sio
import multiprocessing as mp


def _resolve_paths():
    run_dir = sys.argv[1] if len(sys.argv) > 1 else "out"
    env_dir = sys.argv[2] if len(sys.argv) > 2 else None
    if env_dir:
        sys.path.insert(0, env_dir)
    return run_dir


RUN_DIR = _resolve_paths()

import cochlear_model  # noqa: E402  pylint: disable=wrong-import-position


Oversampling = 1
sectionsNo = 1000
p0 = float(2e-5)
par = sio.loadmat(os.path.join(RUN_DIR, "input.mat"))

probes = np.array(par["probes"])
probe_points = probes
Fs = par["Fs"][0][0]
stim = par["stim"]
spl = np.array(par["spl"][0])
channels = int(par["channels"][0][0])
subjectNo = int(par["subject"])
norm_factor = p0 * 10.0 ** (spl / 20.0)
sheraPo = 0.06
irr_on = np.array(par["irregularities"])

print("running cochlear simulation")

for i in range(channels):
    stim[i] = stim[i] * norm_factor[i]

sig = stim
cochlear_list = [
    [cochlear_model.cochlea_model(), sig[i], irr_on[0][i], i] for i in range(channels)
]


def _write_array(filename, array):
    with open(os.path.join(RUN_DIR, filename), "wb") as f:
        np.array(array, dtype="=d").tofile(f)


def solve_one_cochlea(model):
    i = model[3]
    coch = model[0]
    coch.init_model(
        model[1],
        Oversampling * Fs,
        sectionsNo,
        probe_points,
        Zweig_irregularities=model[2],
        sheraPo=sheraPo,
        subject=subjectNo,
    )
    coch.solve()
    _write_array("v" + str(i + 1) + ".np", coch.Vsolution)
    _write_array("y" + str(i + 1) + ".np", coch.Ysolution)
    _write_array("E" + str(i + 1) + ".np", coch.oto_emission)
    _write_array("F" + str(i + 1) + ".np", coch.cf)


if __name__ == "__main__":
    p = mp.Pool(1, maxtasksperchild=1)
    p.map(solve_one_cochlea, cochlear_list)
    p.close()
    p.join()
