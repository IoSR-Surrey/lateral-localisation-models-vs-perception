# DeSena2013

> E. De Sena, H. Hacihabiboglu, and Z. Cvetkovic, 'Analysis and design of multichannel 
systems for perceptual sound field reconstruction', *IEEE Trans. Audio, Speech, Lang. Process.*, 
vol. 21, no. 8, pp. 1653–1665, Aug. 2013, doi: [10.1109/TASL.2013.2260152](https://doi.org/10.1109/TASL.2013.2260152).


## Files required

| Path | Used by |
| --- | --- |
| `results_localisation_desena2013/<listener>/response_sm1.mat` … `response_sm4.mat` | `load_listexp_data('desena2013')` (one sub-folder per listener) |
| `output_files_desena2013/<angle>_<method>_<lsp>.txt` (209 files) | `stimuli/generate_stimuli.m` (loudspeaker rendering filters, 44.1 kHz); only needed to recompute model outputs |
| `desena2013_filter_metadata.mat` | Cache created automatically by `data_analysis/re_compute_desena2013_lsp_filter_metadata.m` from the txt files |

## How to obtain

The perceptual responses and the loudspeaker rendering filters are **not
publicly available**. They are available from the authors on request.
