#! /bin/bash

elm make elm/compare/Main.elm --output elm/compare/main.js
echo "Running 'elm reactor'..."
echo "http://localhost:8000/elm/compare/index.html"
elm reactor
