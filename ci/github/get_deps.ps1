#!/usr/bin/env pwsh
# Build the Windows native dependencies with vcpkg.
#
# Requires VCPKG_ROOT to point at a bootstrapped vcpkg checkout.  When run
# under GitHub Actions the resulting paths are exported to the job environment;
# otherwise they are set for the current session only.

$ErrorActionPreference = 'Stop'

if (-not $env:VCPKG_ROOT) {
    throw 'VCPKG_ROOT is not set; bootstrap vcpkg first.'
}

$arch = $env:PROCESSOR_ARCHITECTURE
$triplet = switch ($arch) {
    'ARM64' { 'arm64-windows' }
    'AMD64' { 'x64-windows-release' }
    default { throw "Unsupported architecture: $arch" }
}

# Keep in sync with "Prerequisites" in User's Guide.
# Versions come from the pinned VCPKG_COMMIT, not from HDF5_VERSION.
$packages = @(
    'blosc', 'blosc2', 'bzip2', 'hdf5[core,threadsafe,zlib]',
    'lz4', 'lzo', 'snappy', 'zstd', 'zlib'
)

$vcpkgArgs = @(
    'install',
    '--triplet', $triplet,
    '--overlay-triplets', (Join-Path $PSScriptRoot 'vcpkg-triplets'),
    '--clean-after-build'
) + $packages

Write-Host "Building dependencies for $triplet"
& (Join-Path $env:VCPKG_ROOT 'vcpkg.exe') @vcpkgArgs
if ($LASTEXITCODE -ne 0) {
    throw "vcpkg install failed with exit code $LASTEXITCODE"
}

$prefix = Join-Path $env:VCPKG_ROOT "installed\$triplet"

$exports = @(
    "HDF5_DIR=$prefix"
    "BLOSC_DIR=$prefix"
    "BLOSC2_DIR=$prefix"
    "BZIP2_DIR=$prefix"
    "LZO_DIR=$prefix"
    # Makes setup.py resolve c-blosc2 from BLOSC2_DIR rather than the wheel.
    'PYTABLES_NO_BLOSC2_WHEEL=1'
)

$binDir = Join-Path $prefix 'bin'
if ($env:GITHUB_ENV) {
    $exports | Add-Content -Path $env:GITHUB_ENV
    Add-Content -Path $env:GITHUB_PATH -Value $binDir
} else {
    foreach ($entry in $exports) {
        $name, $value = $entry -split '=', 2
        Set-Item -Path "env:$name" -Value $value
    }
    $env:PATH = "$binDir$([System.IO.Path]::PathSeparator)$env:PATH"
}

Write-Host "Dependencies installed to $prefix"
