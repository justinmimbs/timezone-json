#! /bin/bash

elm make elm/compare/Main.elm --output elm/compare/main.js
echo "To compare offset changes used by JS Date and tzdb, start 'elm reactor' and open:"
echo "http://localhost:8000/elm/compare/index.html"
