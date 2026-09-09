# ramirez2024
> M. Ramírez, J. M. Arend, P. Von Gablenz, H. R. Liesefeld, and C. Pörschmann, 'Toward Sound Localization Testing in Virtual Reality to Aid in the Screening of Auditory Processing Disorders', 
*Trends in Hearing*, vol. 28, Jan. 2024, doi: [10.1177/23312165241235463](https://doi.org/10.1177/23312165241235463)

## Files required by the loader

| File | Notes |
| --- | --- |
| `Table S2_Data_Experimental raw data.xlsx` | Supplementary raw data (download) |
| `ramirez2024_trials.mat` | Generated from the xlsx by `convert_ramirez2024_xlsx_to_mat.m` |

`load_listexp_data('ramirez2024')` reads only the `.mat` file.

## How to obtain

The supplementary raw data are published on Zenodo:
<https://doi.org/10.5281/zenodo.10655341>

Either run

```matlab
download_ramirez2024
convert_ramirez2024_xlsx_to_mat
```

or `download_dependencies` from the repository root, or download
`Table S2_Data_Experimental raw data.xlsx` manually, place it
in this folder (keep the file name), then run
`convert_ramirez2024_xlsx_to_mat`. The conversion script also calls
`download_ramirez2024` if the xlsx is missing. This writes
`ramirez2024_trials.mat` next to the xlsx.

Optionally run `verify_ramirez2024_against_paper` to compare the parsed
means with the values reported in the paper.

## Code in this folder

- `download_ramirez2024.m` – fetches the Table S2 xlsx from Zenodo.
- `convert_ramirez2024_xlsx_to_mat.m` – parses the xlsx into a trial table.
- `verify_ramirez2024_against_paper.m` – sanity check against paper RMS errors.
