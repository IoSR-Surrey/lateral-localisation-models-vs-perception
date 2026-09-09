# Simon2010

>L. S. R. Simon and R. Mason, 'Time and level localisation curves for a regularly-spaced octagon loudspeaker array', 
in *Proc. of the 128th AES Convention*, London, UK, 2010. <https://aes.org/publications/elibrary-page/?id=15376>

## Files required by the loader

| File | Notes |
| --- | --- |
| `original data/resultsmain.xls` | Raw per-participant results (70 sheets) |
| `simon2010_trials.mat` | Generated from the xls by `convert_simon2010_xls_to_mat.m` |

`load_listexp_data('simon2010')` reads only the `.mat` file.

## How to obtain

The raw data are **not publicly available**. They are available from the
authors on request. Once you have `resultsmain.xls`, place it in
`aux_data/Simon2010/original data/` and run once from MATLAB:

```matlab
convert_simon2010_xls_to_mat
```
