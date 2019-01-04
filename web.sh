#!/bin/sh

set -eux

rm -fr web.tar.gz build/web
pub get
pub run grinder web
tar -C build/web -zcvf web.tar.gz ./
git checkout gh-pages
tar xf web.tar.gz
