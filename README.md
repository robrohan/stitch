# Stitch

## Running

Export from kobo:

```
stitch -t kobo -i '/media/rob/KOBOeReader/.kobo/KoboReader.sqlite' -o kobo.json
```

Export from kindle:

```
stitch -t kindle -i '/media/rob/Kindle/documents/My Clippings.txt' -o kindle.json
```

## Building from Source

### 

```
make
```

### SQLite

Download the source into vendor (_vendor/sqlite3_). Then run:

```
  sh configure
  make sqlite3.c
```

To build _sqlite3.c_ and _sqlite3.h_. Copy those files into the src directory.
