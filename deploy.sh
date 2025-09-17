#!/bin/bash
set -e

echo "🔨  Limpando build antigo..."
rm -rf build/web

echo "🚀  Rodando build Flutter Web..."
flutter build web

echo "📂  Copiando build para pasta deploy..."
rm -rf deploy/*
cp -r build/web/* deploy/

cd deploy

echo "📦  Commit e push para GitHub..."
git add .
git commit -m "Deploy automático"
git push origin main

echo "✅  Deploy finalizado!"

