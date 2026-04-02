#!/data/data/com.termux/files/usr/bin/bash
########################################################
#  Build Ollama with Vulkan GPU support for Termux
#
#  WARNING: This is experimental.
#  - Needs ~4GB free storage
#  - Takes 20-60 min to compile
#  - Vulkan on Android GPU is still hit-or-miss
#
#  Run: bash build-ollama-vulkan.sh
########################################################

set +e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Ollama + Vulkan Builder for Termux${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# ---- Step 1: Install build dependencies ----
echo -e "${YELLOW}[1/6] Installing build dependencies...${NC}"
pkg update -y
pkg install -y git golang cmake make clang \
    vulkan-loader-android vulkan-headers \
    glslang shaderc

# Verify Vulkan headers exist
if [ ! -f "$PREFIX/include/vulkan/vulkan.h" ]; then
    echo -e "${RED}ERROR: vulkan/vulkan.h not found.${NC}"
    echo "Try: pkg install vulkan-headers"
    exit 1
fi
echo -e "${GREEN}  Build deps installed.${NC}"

# ---- Step 2: Clone ollama ----
echo ""
echo -e "${YELLOW}[2/6] Cloning ollama source...${NC}"
cd ~
if [ -d "ollama" ]; then
    echo "  Found existing ollama dir, pulling latest..."
    cd ollama
    git pull
else
    git clone --depth 1 https://github.com/ollama/ollama.git
    cd ollama
fi
echo -e "${GREEN}  Source ready.${NC}"

# ---- Step 3: Build native libraries with Vulkan ----
echo ""
echo -e "${YELLOW}[3/6] Building native GGML libraries (CPU + Vulkan)...${NC}"
echo "  This takes a while. Go grab a coffee."
echo ""

# Clean previous builds
rm -rf build dist/lib 2>/dev/null
mkdir -p dist/lib

# Build CPU backend first
echo -e "${CYAN}  Building CPU backend...${NC}"
cmake -B build/cpu \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_VULKAN=OFF \
    -DBUILD_SHARED_LIBS=ON
cmake --build build/cpu --parallel $(nproc) 2>&1 | tail -5

# Copy CPU libs
find build/cpu -name "*.so" -exec cp {} dist/lib/ \; 2>/dev/null

# Build Vulkan backend
echo ""
echo -e "${CYAN}  Building Vulkan backend...${NC}"
cmake -B build/vulkan \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_VULKAN=ON \
    -DBUILD_SHARED_LIBS=ON
cmake --build build/vulkan --parallel $(nproc) 2>&1 | tail -5

VULKAN_OK=$?
if [ $VULKAN_OK -ne 0 ]; then
    echo -e "${RED}  Vulkan build failed. Trying alternative flags...${NC}"
    # Retry with explicit paths
    cmake -B build/vulkan \
        -DCMAKE_BUILD_TYPE=Release \
        -DGGML_VULKAN=ON \
        -DBUILD_SHARED_LIBS=ON \
        -DVulkan_INCLUDE_DIR="$PREFIX/include" \
        -DVulkan_LIBRARY="$PREFIX/lib/libvulkan.so"
    cmake --build build/vulkan --parallel $(nproc) 2>&1 | tail -5
    VULKAN_OK=$?
fi

if [ $VULKAN_OK -eq 0 ]; then
    # Copy Vulkan libs into a subdirectory ollama can find
    mkdir -p dist/lib/vulkan
    find build/vulkan -name "*.so" -exec cp {} dist/lib/vulkan/ \; 2>/dev/null
    echo -e "${GREEN}  Vulkan backend built!${NC}"
else
    echo -e "${RED}  Vulkan backend failed to compile.${NC}"
    echo -e "${RED}  Will continue with CPU-only build.${NC}"
fi

# ---- Step 4: Generate Go bindings ----
echo ""
echo -e "${YELLOW}[4/6] Generating Go bindings...${NC}"
export CGO_ENABLED=1
go generate ./... 2>&1 | tail -5
echo -e "${GREEN}  Go generate done.${NC}"

# ---- Step 5: Build ollama binary ----
echo ""
echo -e "${YELLOW}[5/6] Building ollama binary...${NC}"
mkdir -p dist/bin
go build -trimpath -o dist/bin/ollama . 2>&1 | tail -5

if [ ! -f dist/bin/ollama ]; then
    echo -e "${RED}  Binary build FAILED.${NC}"
    echo "  Check errors above. Common issues:"
    echo "    - Not enough storage (need ~4GB)"
    echo "    - Not enough RAM (close other apps)"
    echo "    - Go version too old (need 1.22+)"
    exit 1
fi
echo -e "${GREEN}  Binary built!${NC}"

# ---- Step 6: Install ----
echo ""
echo -e "${YELLOW}[6/6] Installing...${NC}"

# Backup existing ollama if any
if [ -f "$PREFIX/bin/ollama" ]; then
    cp "$PREFIX/bin/ollama" "$PREFIX/bin/ollama.bak"
    echo "  Backed up existing ollama to ollama.bak"
fi

# Copy binary
cp dist/bin/ollama "$PREFIX/bin/ollama"
chmod +x "$PREFIX/bin/ollama"

# Copy libraries where ollama can find them
mkdir -p "$PREFIX/lib/ollama"
cp -r dist/lib/* "$PREFIX/lib/ollama/" 2>/dev/null

echo -e "${GREEN}  Installed to $PREFIX/bin/ollama${NC}"

# ---- Done ----
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Build complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "  To run with Vulkan GPU:"
echo ""
echo "    Session 1:"
echo "      termux-wake-lock"
echo "      OLLAMA_VULKAN=1 ollama serve"
echo ""
echo "    Session 2:"
echo "      ollama run llama3.2:1b"
echo ""
echo "  Check GPU is detected in the serve logs."
echo "  You should see 'Vulkan' in the device list."
echo ""
echo "  If Vulkan doesn't work, fallback to CPU:"
echo "      ollama serve"
echo ""
echo "  To restore the original pkg version:"
echo "      cp $PREFIX/bin/ollama.bak $PREFIX/bin/ollama"
echo ""
