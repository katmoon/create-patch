# Patch generation tool

## Description
Generates a patch for a single branch of a single repository using 'git diff'.
Generates a git and a composer version of the patch.
The tool should be run from the folder where the repository is located.

## Requirements
/bin/bash

## Configuration
```
cp .env.example .env
```
Specify the path to the patch converter tool in the .env file.

## Usage
```
create-patch.sh -h
```
