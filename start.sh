#!/usr/bin/env bash

# Interrompe lo script in caso di errore
set -e

echo "========================================="
echo "🚀 Inizializzazione progetto OnListClub..."
echo "========================================="

# Nix Flakes richiede che i file siano tracciati da Git
if [ ! -d ".git" ]; then
  echo "📦 Inizializzazione repository Git..."
  git init
fi

# Aggiunge il flake.nix a git se non è già tracciato
git add flake.nix

# 1. Avvia i servizi Docker in background (se esiste il file compose)
if [ -f "docker-compose.yml" ]; then
  echo "🐳 Avvio dei servizi Docker..."
  docker compose up -d
fi

# 2. Avvia l'ambiente Nix ed esegue i comandi Flutter
echo "❄️  Attivazione ambiente Nix e avvio app..."
nix develop --command bash -c "
  # Se il progetto Flutter non esiste ancora, decommenta la riga sotto per crearlo
  # flutter create . 
  
  echo '📦 Download dipendenze Flutter...'
  flutter pub get
  
  echo '📱 Avvio di Flutter...'
  # Esempio: avvia la versione web o nativa. 
  # Per scegliere un device specifico usa: flutter run -d chrome
  flutter run
"