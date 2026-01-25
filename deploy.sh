#!/bin/bash

# Exit on error
set -e

echo "🚀 Building Flutter Web..."
flutter build web --base-href /khatabook/ --release

cd build/web

# Ensure clean git state for deployment
rm -rf .git

echo "📦 Initializing Deployment Repo..."
git init
git checkout -b gh-pages

# Add all files
git add .
git commit -m "Deploy Flutter Web to GitHub Pages"

# Add the target remote (Angular repo)
echo "🔗 Setting remote to khatabook..."
git remote add origin https://github.com/raushanc107/khatabook.git

echo "📤 Pushing to GitHub (this replaces the Angular content)..."
# Force push to gh-pages branch
git push -f origin gh-pages

echo "✅ Deployment Complete! Visit https://raushanc107.github.io/khatabook/"
