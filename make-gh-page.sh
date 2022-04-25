#!/usr/bin/bash

# Make all "index.html" variants end on ".html"
find . -name 'index.html@*' | while read path; do
  git mv $path $(echo $path | sed -r 's/\.html(@.*)/\1.html/')
done

find . -name 'index*.html' | while read path; do
  # Fix sort links
  sed -ri 's/href="\?(C=[^"]+)"/href="index@\1.html"/g' $path

  # Fix parent directory links
  sed -ri 's/href="[^"]+(">Parent Directory)/href="..\/\1/' $path

  # Fix icon paths
  sed -ri 's/<img src="\/icons\//<img src="\/ftp.tvdr.de\/icons\//g' $path
done
