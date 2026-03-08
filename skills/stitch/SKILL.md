---
name: stitch
description: Run `stitch` to extract highlights from a Kindle or Kobo e-reader and write them to a JSON file. Use when the user wants to dump, export, or query their e-reader highlights.
---

The user wants to run `stitch` to extract e-reader highlights.

If arguments were provided (`$ARGUMENTS`), use them to infer the device type and/or output file. Otherwise, ask the user which device type they want (`kobo` or `kindle`) and whether they have an input path or want to rely on environment variables.

## How to run stitch

```
stitch [-i input_file] [-o output_file.json] -t [kobo|kindle]
```

**Options:**
- `-t kobo` or `-t kindle` — **required**
- `-i <path>` — path to the input file (overrides env vars and defaults)
- `-o <path>` — output JSON file (defaults to `kobo.json` or `kindle.json`)

**Typical input paths:**

| OS | Device | Path |
|----|--------|------|
| macOS | Kindle | `/Volumes/Kindle/documents/My Clippings.txt` |
| macOS | Kobo | `/Volumes/KOBOeReader/.kobo/KoboReader.sqlite` |
| Linux | Kindle | `/media/$USER/Kindle/documents/My Clippings.txt` |
| Linux | Kobo | `/media/$USER/KOBOeReader/.kobo/KoboReader.sqlite` |

**Environment variables (set these to skip `-i` each time):**
- `STITCH_KOBO` — path to the Kobo SQLite file
- `STITCH_KINDLE` — path to the Kindle clippings file

## Prerequisites

Before running stitch, make sure the binary is installed. If `stitch` is not found on the PATH, tell the user to download the appropriate binary for their platform from:

https://github.com/robrohan/stitch/releases

On macOS, after downloading, the user must right-click the binary in Finder and select "Open" once to bypass the unsigned binary warning before it can be used from the terminal.

## Steps

1. Check that `stitch` is available by running `which stitch`. If not found, stop and direct the user to download it from the releases page above.
2. Determine device type from `$ARGUMENTS` or ask the user.
2. Determine input path: check if `STITCH_KOBO` / `STITCH_KINDLE` is set, or ask the user for the path.
3. Run `stitch -t <type> [-i <input>] [-o <output>]` using the Bash tool.
4. If successful, read back the output JSON with the Read tool and summarise:
   - How many highlights were found
   - How many unique books/titles
   - Any annotations present
5. Offer to filter or query the results further with `jq`.

## Notes

- The output always ends with a trailing `{}` — this is expected, not an error.
- If the device file is not accessible, stitch exits `0` but logs a warning to stderr. Tell the user to check the device is mounted and the path is correct.
- `id` fields are base64-encoded SpookyHashes of the highlight text — stable across runs.
