# HRTFs

The paper averages model predictions over eight individual HRTF sets, all
placed in `aux_data/HRTFs/collection/` (the default `multi_hrtf_sofa_dir`):

| File | Source |
| --- | --- |
| `P0001_FreeFieldCompMinPhase_48kHz.sofa` | SONICOM HRTF dataset, participant P0001 |
| `P0003_FreeFieldCompMinPhase_48kHz.sofa` | SONICOM HRTF dataset, participant P0003 |
| `P0005_FreeFieldCompMinPhase_48kHz.sofa` | SONICOM HRTF dataset, participant P0005 |
| `P0006_FreeFieldCompMinPhase_48kHz.sofa` | SONICOM HRTF dataset, participant P0006 |
| `hrtf d_nh1059.sofa` | ARI HRTF database, subject NH1059 |
| `hrtf d_nh1188.sofa` | ARI HRTF database, subject NH1188 |
| `hrtf d_nh1189.sofa` | ARI HRTF database, subject NH1189 |
| `hrtf d_nh1190.sofa` | ARI HRTF database, subject NH1190 |

Run from MATLAB (any working directory):

```matlab
download_hrtfs
```

From the repository root, `download_dependencies` also fetches these files.

Sources:

- SONICOM HRTF dataset:
  <https://www.axdesign.co.uk/tools-and-devices/sonicom-hrtf-dataset>
  (files served from `https://transfer.ic.ac.uk:9090/2022_SONICOM-HRTF-DATASET/`).
- ARI HRTF database:
  <https://www.oeaw.ac.at/isf/das-institut/software/hrtf-database>
  (files served from <https://sofacoustics.org/data/database/ari/>).

Keep the file names exactly as listed (including the space in the ARI names):
the cached model outputs in `model_output_data/` are keyed by SOFA basename,
and the aggregate label `MULTI_collection` is derived from the folder name.
`*.sofa` files are git-ignored.
