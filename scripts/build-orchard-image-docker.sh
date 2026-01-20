#!/usr/bin/env bash
# ABOUTME: Build NixOS qcow2 image using Docker Linux builder
# ABOUTME: Works around macOS limitations for building Linux images

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
IMAGE_NAME="orchard"
OUTPUT_DIR="$ROOT_DIR/images"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Build NixOS qcow2 image using Docker as Linux builder.

OPTIONS:
    -h, --help              Show this help message
    -v, --verbose           Enable verbose output

EXAMPLES:
    # Build image
    $0

    # Build with verbose output
    $0 --verbose

EOF
}

# Parse command line arguments
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check for Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not running"
        return 1
    fi
    
    # Check Docker is running
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running"
        return 1
    fi
    
    log_info "Prerequisites check passed"
    return 0
}

# Build using Docker
build_with_docker() {
    log_info "Building NixOS image using Docker..."
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Create a temporary build script
    cat > "$OUTPUT_DIR/build-in-docker.sh" << 'EOSCRIPT'
#!/usr/bin/env bash
set -euo pipefail

# Install Nix in container
if ! command -v nix &> /dev/null; then
    echo "Installing Nix..."
    curl -L https://nixos.org/nix/install | sh -s -- --daemon --yes
    source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

# Enable flakes
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf

# Build the image
cd /workspace
nix build .#images.orchard --print-build-logs

# Copy result to output
if [ -d result ]; then
    find result -name "*.qcow2" -o -name "*.qcow" | head -1 | xargs -I {} cp {} /output/nixos-orchard.qcow2
    echo "Image built successfully"
else
    echo "Build failed - no result directory"
    exit 1
fi
EOSCRIPT

    chmod +x "$OUTPUT_DIR/build-in-docker.sh"
    
    # Run Docker container
    log_info "Starting Docker build container..."
    
    docker run --rm \
        -v "$ROOT_DIR:/workspace:ro" \
        -v "$OUTPUT_DIR:/output:rw" \
        -v "$OUTPUT_DIR/build-in-docker.sh:/build.sh:ro" \
        --platform linux/amd64 \
        nixos/nix:latest \
        /build.sh
    
    # Clean up
    rm -f "$OUTPUT_DIR/build-in-docker.sh"
    
    # Check if image was created
    if [[ -f "$OUTPUT_DIR/nixos-${IMAGE_NAME}.qcow2" ]]; then
        local image_size=$(du -h "$OUTPUT_DIR/nixos-${IMAGE_NAME}.qcow2" | cut -f1)
        log_info "Image built successfully: $OUTPUT_DIR/nixos-${IMAGE_NAME}.qcow2 (${image_size})"
        return 0
    else
        log_error "Image build failed - no output file"
        return 1
    fi
}

# Alternative: Use nix-docker
build_with_nix_docker() {
    log_info "Setting up Docker as Nix builder..."
    
    # Check if docker builder already exists
    if ! nix store ping --store docker://nix-docker 2>/dev/null; then
        log_info "Creating Docker builder..."
        
        # Run nix-docker container
        docker run -d \
            --name nix-docker \
            --restart always \
            -p 2376:2376 \
            nixos/nix:latest \
            sh -c "nix-daemon --daemon"
    fi
    
    # Build using docker builder
    log_info "Building with Docker builder..."
    nix build .#images.orchard \
        --builders "docker://nix-docker x86_64-linux" \
        --max-jobs 0 \
        --print-build-logs
    
    # Copy result
    if [[ -d result ]]; then
        mkdir -p "$OUTPUT_DIR"
        find result -name "*.qcow2" -o -name "*.qcow" | head -1 | xargs -I {} cp {} "$OUTPUT_DIR/nixos-${IMAGE_NAME}.qcow2"
        log_info "Image copied to $OUTPUT_DIR/nixos-${IMAGE_NAME}.qcow2"
    fi
}

# Main execution
main() {
    log_info "Starting NixOS image build with Docker"
    
    # Check prerequisites
    if ! check_prerequisites; then
        exit 1
    fi
    
    # Try direct Docker build
    if ! build_with_docker; then
        log_error "Docker build failed"
        exit 1
    fi
    
    log_info "Build complete!"
    log_info ""
    log_info "Next steps:"
    log_info "1. Image is at: $OUTPUT_DIR/nixos-${IMAGE_NAME}.qcow2"
    log_info "2. Run: ./scripts/provision-orchard-nixos.sh"
    log_info ""
}

# Run main function
main "$@"