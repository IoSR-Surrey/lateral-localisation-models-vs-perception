# frank2013

> M. Frank, 'Phantom Sources using Multiple Loudspeakers in the Horizontal Plane', 
Doctoral dissertation, University of Music and Performing Arts Graz, Graz, Austria, 2013. 
<https://phaidra.kug.ac.at/o:7008>

## Files required by the loader

| File | Used by |
| --- | --- |
| `frankPhD2013lococ.txt` | `read_frank2013_lococ.m` (via `load_listexp_data('frank2013')`) |

## How to obtain

The raw data are published by IEM Graz as part of the open
"Listening experiment data" collection:
<https://opendata.iem.at/projects/listening_experiment_data/>

Either run

```matlab
download_frank2013
```

or `download_dependencies` from the repository root, or download
`frankPhD2013lococ.txt` manually and place it in this folder.

## Code in this folder

- `download_frank2013.m` – fetches the data file.
- `read_frank2013_lococ.m` – parses the raw trial table.
- `frank2013_listener_pose.m` – listener geometry for the off-centre position.
- `verify_frank2013_against_thesis.m` – sanity check against thesis figures.
