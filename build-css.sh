#!/bin/bash

sass assets_source/stylesheets/application.scss assets/stylesheets/application.css
gzip --keep --best --force assets/stylesheets/application.css
