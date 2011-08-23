#!/bin/bash

GTK_SOURCE_VIEW_DIR=$HOME/.local/share/gtksourceview-2.0/

mkdir -p $GTK_SOURCE_VIEW_DIR

cp -r language-specs $GTK_SOURCE_VIEW_DIR
cp -r styles $GTK_SOURCE_VIEW_DIR
