#!/usr/bin/env bash
set -euo pipefail

# Color codes for pretty output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Starting Rebuild Pipeline ===${NC}"

# Step 0: Check if Git directory is dirty before starting
echo -e "\n${BLUE}[Step 0] Checking Git working tree status...${NC}"
if [ -n "$(git status --porcelain)" ]; then
    echo -e "${RED}Error: Git working directory is dirty. Please clean the branch or commit your manual changes before running the rebuild pipeline.${NC}"
    git status -s
    exit 1
fi
echo -e "${GREEN}Git working tree is clean.${NC}"

# Step 1: Lint, format, and build wabi
echo -e "\n${BLUE}[Step 1] Linting, formatting, and building wabi...${NC}"
(
    cd wabi
    echo "Running cargo clippy..."
    cargo clippy --all-targets -- -D warnings
    echo "Running cargo fmt..."
    cargo fmt --all
    echo "Building release and installing..."
    cargo build --release
    make install
)

# Step 2: Format QML files and run nixfmt
echo -e "\n${BLUE}[Step 2] Formatting and linting QML / Nix files...${NC}"
echo "Formatting QML files..."
nix-shell -p qt6.qtdeclarative --run 'find modules/features/wm/quickshell -name "*.qml" -exec qmlformat -i {} +'

echo "Linting QML files..."
nix-shell -p qt6.qtdeclarative --run 'find modules/features/wm/quickshell -name "*.qml" -exec qmllint {} +'

echo "Formatting Nix files..."
find . -name "*.nix" -not -path "./.git/*" -not -path "./wabi/*" | xargs nixfmt

echo "Checking Nix formatting..."
find . -name "*.nix" -not -path "./.git/*" -not -path "./wabi/*" | xargs nixfmt -c

# Step 3: Nix flake check
echo -e "\n${BLUE}[Step 3] Running nix flake check...${NC}"
nix flake check

# Step 4: Git clean check & commit formatting changes if any
echo -e "\n${BLUE}[Step 4] Checking for auto-formatting changes...${NC}"
if [ -n "$(git status --porcelain)" ]; then
    echo -e "${YELLOW}Formatting changed some files. Committing formatting updates...${NC}"
    git add -A
    git commit -m "style: auto-format Nix and QML files"
    echo -e "${GREEN}Formatting changes committed successfully.${NC}"
else
    echo -e "${GREEN}No formatting changes detected. Working tree remains clean.${NC}"
fi

# Step 5: System Rebuild
echo -e "\n${BLUE}[Step 5] Rebuilding NixOS configuration...${NC}"
sudo nixos-rebuild switch --flake .#apostrophe

echo -e "\n${GREEN}=== Rebuild Pipeline Completed Successfully ===${NC}"
