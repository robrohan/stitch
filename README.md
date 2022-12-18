# Stitch

Stich is a command line application that extracts highlights from Kindle and Kobo devices. It puts the output into
a local json file which can then be further processed.

Quick example:

```
```

[Video of it running](https://youtu.be/SNt2uDLyBnU?t=292)

## Running

### Mac

Since the binary is not signed, you must first let Mac OS know the binary is ok to run. Do the following:

- Download the zip file
- Double click it. It will extract the file.
- Using Finder, right click on the file _stitch_, and select _Open_.
- A terimal window will open, and then close.

After that process, you can then use the binary via terminal. 

Now, you can open terminal.app, and run:

```
% ./stitch -h
[KS] main (src/main.c:27) Using user: robrohan

Usage: ./stitch [-i input_file] [-o output_file.json] -t [kobo|kindle]

Input example:
	Kindle: '/media/robrohan/Kindle/documents/My Clippings.txt'
	Kobo: '/media/robrohan/KOBOeReader/.kobo/KoboReader.sqlite'
```

**Importing from Kindle**

Here is an example of using Mac OS to extract highlights from Kindle:

```
./stitch -t kindle -i "/Volumes/Kindle/documents/My Clippings.txt" -o kindle.json
```

**Importing from Kobo**

Kobo is similar:

```
./stitch -t kobo -i "/Volumes/KOBOeReader/.kobo/KoboReader.sqlite" -o kobo.json
```

### Linux

Importing data on Linux is similar to Mac. However the path is based on the current user not
a global location:

**Kobo**

```
stitch -t kobo -i '/media/username/KOBOeReader/.kobo/KoboReader.sqlite' -o kobo.json
```

**indle**

```
stitch -t kindle -i '/media/username/Kindle/documents/My Clippings.txt' -o kindle.json
```

## Building from Source

Stich is using _clang_ by default. You'll need to make sure that is installed and setup.

### The Basics

```
make
```

### SQLite

SQLite code is already included in the source directory, however to update the code you'll need
to do the following:

- Download the source into vendor (_vendor/sqlite3_). 
- Then run from within that directory:
```
  sh configure
  make sqlite3.c
```
- Then move _sqlite3.c_ and _sqlite3.h_ into the src directory.
- From that point forward, the _vendor/sqlite3_ directory is not used.

