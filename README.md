# lateral-localisation-models-vs-perception

MATLAB code to compare computational models of perceived lateral angle against
perceptual data from multichannel phantom-source localisation experiments, 
and to reproduce the figures and tables of the accompanying paper (submitted for review):

> Daugintis, R., Lladó, P., Cvetković, Z., and De Sena, E. (2026). 
*Comparative evaluation of lateral localisation models in multichannel sound reproduction.*

Thirteen models are compared (lindemann1986, breebaart2001, faller2004, 
may2011, dietz2011, takanen2013, vecchiotti2019 (WaveLoc), saddler2024 (phaselocknet), 
llado2025, wang2026, and the energy-vector
models rE-gerzon1992, rE-stitt2016 and rE-kurz2017) against five datasets (data_simon2010,
data_desena2013, data_frank2013, data_ramirez2024, data_llado2026), with model predictions
averaged over eight individual HRTFs.

## What this repository produces

| Paper item | Script | Output file |
| --- | --- | --- |
| Combined-dataset model fit grid | `compare_models_to_perceptual_data` | `figures/model_summary_simon2010_desena2013_frank2013_ramirez2024_llado2026.pdf` |
| Off-centre model fit grid | `compare_models_to_perceptual_data` | `figures/model_summary_off_centre.pdf` |
| R² comparison plot | `build_model_output_r2_table` | `figures/model_output_r2_comparison.pdf` |
| R² / slope table | `build_model_output_r2_table` | `model_output_data/model_output_r2_table.{csv,tex}` |
| Average run-time table | `build_model_output_r2_table` | `model_output_data/model_output_runtime_table.tex` |

Both scripts work from cached per-model outputs in `model_output_data/`
(see [Model output cache](#model-output-cache)); recomputing the models from
scratch is optional and needs the full set of external dependencies below.

## Requirements

### Always needed (plot from cache)

- MATLAB R2023a or newer with the Statistics and Machine Learning Toolbox
  (bootstrap CIs). The Parallel Computing Toolbox is recommended for
  recomputation but not required.
- [Auditory Modelling Toolbox (AMT) 1.6](https://amtoolbox.org/) – provides the
  model implementations and the SOFA API (`SOFAload`, `sph2hor`, …) used to
  read HRTFs and perceptual data. Point `amt_dir` in `local_paths.m` at it.
- The perceptual datasets (see [Perceptual data](#perceptual-data)). The fits
  shown in the figures are computed at plot time from the cached model
  predictions and the perceptual responses, so the datasets are needed even
  when nothing is recomputed.
- The eight HRTF SOFA files. Run `download_dependencies` from the repository
  root (or `aux_data/HRTFs/download_hrtfs.m`). They are used to enumerate
  the HRTF-specific cache files.

### Only needed to recompute model outputs

| Model(s) | Dependency | `local_paths.m` field(s) |
| --- | --- | --- |
| faller2004 | [PrecSep toolbox](https://www.iosr.uk/software/index.php#PrecSep) (`prec_fallermerimaa`) | `precsep_dir` |
| rE-stitt2016, rE-gerzon1992 | [Stitt et al. extended energy-vector MATLAB code](https://www.ssa-plugins.com/matlab-code/). This third-party code is not included; install it with `models/extended_re/download_stitt2016.m`. | — |
| takanen2013 | Python 3 with `numpy`/`scipy` for the AMT `verhulst2012` periphery (any venv; the phaselocknet venv works) | `amt_python` |
| saddler2024 | [phaselocknet_torch_CIAT_evaluation](https://github.com/IoSR-Surrey/phaselocknet_torch_CIAT_evaluation) fork with its Python virtual environment | `phaselocknet_dir`, `phaselocknet_python` |
| wang2026 | private `ei_yang` repository (evaluation is based on `IEEE25_models/P3.keras` model) with its Python virtual environment (TensorFlow, brian2hears) | `ei_yang_dir`, `ei_yang_python` |
| vecchiotti2019 | Docker plus the [IoSR-Surrey WaveLoc fork](https://github.com/IoSR-Surrey/WaveLoc); see the [WaveLoc dependency](#waveloc-dependency) instructions below. | `waveloc_dir`, `docker_bin` |

#### Stitt energy-vector dependency

Recomputing `rE-stitt2016` or `rE-gerzon1992` requires the original Stitt et
al. MATLAB implementation. Install it from the repository root with
`download_dependencies` (or `download_stitt2016` on its own):

```matlab
download_stitt2016
```

The script downloads and extracts
[`ExtendedEnergyVector_public.zip`](https://www.ssa-plugins.com/wp-content/uploads/2017/12/ExtendedEnergyVector_public.zip)
into the git-ignored `models/extended_re/stitt2016/` folder. The third-party
code is published at <https://www.ssa-plugins.com/matlab-code/> and is not
included in this repository.

#### WaveLoc dependency

Recomputing `vecchiotti2019` requires Docker. Start Docker Desktop 
(or another Docker daemon) before running the model. The model wrapper
automatically starts an existing `waveloc_inference` container or creates one
from `python:3.7-bullseye`, mounts the WaveLoc checkout, and installs its Python
dependencies on first use. A `waveloc_inference` container created by the
fork's dev-container setup is also reused.

## Setup

1. Clone the repository and open MATLAB in its root folder.
2. Create your machine-specific configuration:

   ```matlab
   copyfile('local_paths_template.m', 'local_paths.m')
   edit local_paths.m
   ```

   `local_paths.m` is git-ignored. Every field can also be overridden with an
   environment variable (`AMT_DIR`, `PRECSEP_DIR`, `PHASELOCKNET_DIR`,
   `PHASELOCKNET_PYTHON`, `EI_YANG_DIR`, `EI_YANG_PYTHON`, `AMT_PYTHON`,
   `WAVELOC_DIR`, `DOCKER_BIN`). Fields for models you do not recompute can
   stay empty.
3. Download the publicly available data and third-party code:

   ```matlab
   download_dependencies
   ```

   This fetches the eight HRTF SOFA files, frank2013, ramirez2024 (and
   converts it to `.mat`), and the Stitt et al. energy-vector MATLAB code.
   Existing files are skipped. The Command Window then lists datasets that
   still have to be obtained from the authors (next section).
4. Obtain any remaining perceptual data (next section).
5. Obtain the model-output cache, or recompute it (section after).

`setup_paths.m` (called automatically by both entry scripts) adds the code
folders to the MATLAB path, starts the AMT and adds PrecSep when configured.

## Perceptual data

No perceptual data are tracked in this repository (third-party data). Each
`aux_data/<dataset>/README.md` lists the exact files the loaders expect.

| Dataset | Availability | Steps |
| --- | --- | --- |
| frank2013 | public ([IEM ListExData](https://opendata.iem.at/projects/listening_experiment_data/)) | included in `download_dependencies` (or `download_frank2013`) |
| ramirez2024 | public ([Zenodo 10.5281/zenodo.10655341](https://doi.org/10.5281/zenodo.10655341)) | included in `download_dependencies` (or `download_ramirez2024` then `convert_ramirez2024_xlsx_to_mat`) |
| simon2010 | on request from the authors | `original data/resultsmain.xls` → `convert_simon2010_xls_to_mat` |
| desena2013 | on request from the authors | `results_localisation_desena2013/<listener>/response_sm*.mat` (+ `output_files_desena2013/*.txt` to recompute) |
| llado2026 | on request from the authors | `expResultsTable.mat`, `llado2026_allresults.mat` (+ `stimuli_KEMAR/wavfiles/*.wav` to recompute) |

To run with a subset of datasets, edit `combined_dataset_ids` in both entry
scripts (same set of ids; the order in `build_model_output_r2_table.m` sets the
table column order).

## Model output cache

Model predictions are cached as one `.mat` file per dataset, HRTF and model:

```
model_output_data/MC_MODEL_OUTPUT_<dataset>_<HRTF>_<model>.mat
```

Geometry-only models (`kurz2017`, `stitt2016`, `rE`) use the HRTF label
`GEOMETRY`. The paper uses 415 such files (5 datasets × (8 HRTFs × 10
HRTF-dependent models + 3 geometry models)). Cache files for the llado2025 model
may carry the legacy id `desena2020` (`*_desena2020.mat`); the loaders map it
to `llado2025` automatically.

**Option A – obtain the cache used for the paper.**
Currently, the cache files are available from the authors. We are planning 
on uploading them to a public repository at the release of the paper. The obtained 
`.mat` files should be placed into `model_output_data/`. 
Each file also stores the per-condition mean perceptual responses it was fitted against, 
plus timing information used for the run-time table.

**Option B – recompute.** Install the dependencies listed above, then in
`compare_models_to_perceptual_data.m` set

```matlab
run_mode = 'combined_recompute';
```

and run the script. Each dataset is evaluated for each HRTF and the results are
written to `model_output_data/`. This will take a while to run, especially 
`takanen2013` and `saddler2024` models. Set individual `run_*` flags to `false` 
to skip models whose dependencies you do not have, or use 
`recompute_model_ids = {'dietz2011'}` to refresh a single model while keeping 
the rest of the cache.

## Reproducing the figures and tables

With `local_paths.m`, the HRTFs, the perceptual data and the cache in place:

```matlab
compare_models_to_perceptual_data   % combined + off-centre fit grids
build_model_output_r2_table         % R^2 plot, R^2/slope table, run-time table
```

Defaults in `compare_models_to_perceptual_data.m` match the paper:
`run_mode = 'combined_from_cache'`, `run_multi_hrtf = true`,
`multi_hrtf_sofa_dir = 'aux_data/HRTFs/collection/'`, 10 000 bootstrap
resamples (seed 42) for the R² and slope confidence intervals,
`simon2010_hemisphere = 'separate'`. Figures are written as vector PDFs to
`figures/`; tables to `model_output_data/`.

Setting `run_mode = 'single'` and `listexp_data_id` evaluates/plots one dataset
on its own (not part of the paper; also used internally by
`combined_recompute`).

## Repository layout

```
compare_models_to_perceptual_data.m   Main entry point: model fits (figures).
build_model_output_r2_table.m         Post-processing: R^2 / slope / run-time tables and R^2 plot.
download_dependencies.m               Fetches public HRTFs, datasets, and Stitt code.
setup_paths.m                         Path setup (code folders, AMT, PrecSep).
local_paths_template.m                Template for the git-ignored local_paths.m.

models/                Model wrappers, one subfolder per model (eval_<model>.m + helpers).
  common/              Shared periphery and ITD/ILD-to-angle lookups.
  extended_re/         Energy-vector wrappers (rE, stitt2016, kurz2017) and
                       download_stitt2016.m for the excluded third-party code.
  saddler2024/, wang2026/, vecchiotti2019/, takanen2013/   Python / Docker bridges.
data_analysis/         Data loading, cache assembly, error metrics, bootstrap CIs.
stimuli/               Binaural stimulus generation and HRTF convolution.
plotting/              Grid/summary plotting and LaTeX figure export.
aux_data/              Data folders (code + READMEs tracked; data git-ignored).
  HRTFs/               download_hrtfs.m -> collection/*.sofa
  <dataset>/           Loader helpers, converters and download instructions.
model_output_data/     Cache files and generated tables (git-ignored).
templates/             Cached model templates per HRTF (generated, git-ignored).
figures/               Generated figures (git-ignored).
```

## How it fits together

`compare_models_to_perceptual_data.m` loads each dataset with
`load_listexp_data`, generates the matching binaural stimuli with
`generate_stimuli` for each HRTF, runs every enabled model through its
`models/<model>/eval_<model>.m` wrapper (`evaluate_models_for_hrtf`), saves the
predictions as per-model cache pieces, averages them over HRTFs
(`aggregate_hrtf_predictions`), fits them to the perceptual responses
(`func_errormetrics`, `bootstrap_r2_ci`, `bootstrap_slope_ci`) and plots the
grids (`plot_estimatederror_grid`, `run_combined_off_centre_plot`).
`build_model_output_r2_table.m` assembles the same cache pieces
(`assemble_model_output`), computes per-dataset and pooled R²/slope with
CIs and writes the CSV/LaTeX tables and the R² plot.

## License and citation

License: to be added. If you use this code, please cite the paper above.
Third-party model code (AMT, PrecSep, the downloaded Stitt et al.
implementation, and the Python/Docker model repositories) remains under its
respective licenses.
