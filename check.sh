#!/bin/sh
# zipalign test suite

set -e

# Colors for output (disabled if not a terminal)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
fi

PASS=0
FAIL=0
ZIPALIGN="${ZIPALIGN:-./zipalign}"

log_pass() {
    PASS=$((PASS + 1))
    printf "${GREEN}PASS${NC}: %s\n" "$1"
}

log_fail() {
    FAIL=$((FAIL + 1))
    printf "${RED}FAIL${NC}: %s\n" "$1"
}

log_info() {
    printf "${YELLOW}INFO${NC}: %s\n" "$1"
}

# Create temp directory
TMPDIR=$(mktemp -d) || exit

log_info "Using temp directory: $TMPDIR"
log_info "Testing zipalign: $ZIPALIGN"

# Verify zipalign exists and is executable
if [ ! -x "$ZIPALIGN" ]; then
    printf "${RED}ERROR${NC}: zipalign not found or not executable at: %s\n" "$ZIPALIGN"
    exit 1
fi

########################################
# Test 1: Basic functionality - create new archive
########################################
log_info "Test 1: Create new archive with single file"
echo "Hello, World!" > "$TMPDIR/hello.txt"
$ZIPALIGN "$TMPDIR/test1.zip" "$TMPDIR/hello.txt"
if unzip -t "$TMPDIR/test1.zip" >/dev/null 2>&1; then
    log_pass "Created valid ZIP archive"
else
    log_fail "Failed to create valid ZIP archive"
fi

########################################
# Test 2: Verify file contents
########################################
log_info "Test 2: Verify extracted file contents match original"
mkdir -p "$TMPDIR/extract1"
unzip -q -d "$TMPDIR/extract1" "$TMPDIR/test1.zip"
# Find the extracted file (may be in subdirectory based on path)
EXTRACTED=$(find "$TMPDIR/extract1" -name "hello.txt" -type f | head -1)
if [ -n "$EXTRACTED" ] && diff -q "$TMPDIR/hello.txt" "$EXTRACTED" >/dev/null 2>&1; then
    log_pass "Extracted contents match original"
else
    log_fail "Extracted contents do not match original"
fi

########################################
# Test 3: Multiple files
########################################
log_info "Test 3: Add multiple files to archive"
echo "File A content" > "$TMPDIR/a.txt"
echo "File B content" > "$TMPDIR/b.txt"
echo "File C content" > "$TMPDIR/c.txt"
$ZIPALIGN "$TMPDIR/test3.zip" "$TMPDIR/a.txt" "$TMPDIR/b.txt" "$TMPDIR/c.txt"
COUNT=$(unzip -l "$TMPDIR/test3.zip" 2>/dev/null | grep -c '\.txt$' || true)
if [ "$COUNT" -eq 3 ]; then
    log_pass "Archive contains all 3 files"
else
    log_fail "Archive should contain 3 files, found: $COUNT"
fi

########################################
# Test 4: Junk paths flag (-j)
########################################
log_info "Test 4: Junk paths flag (-j)"
mkdir -p "$TMPDIR/deep/nested/path"
echo "nested file" > "$TMPDIR/deep/nested/path/nested.txt"
$ZIPALIGN -j "$TMPDIR/test4.zip" "$TMPDIR/deep/nested/path/nested.txt"
if unzip -l "$TMPDIR/test4.zip" 2>/dev/null | grep -q "nested.txt" && \
   ! unzip -l "$TMPDIR/test4.zip" 2>/dev/null | grep -q "deep/"; then
    log_pass "Junk paths flag works correctly"
else
    log_fail "Junk paths flag did not strip directory"
fi

########################################
# Test 5: Compression levels
########################################
log_info "Test 5: Compression level 0 (store)"
dd if=/dev/zero bs=1024 count=100 2>/dev/null > "$TMPDIR/zeros.bin"
$ZIPALIGN -0 "$TMPDIR/test5_store.zip" "$TMPDIR/zeros.bin"
STORE_SIZE=$(stat -c%s "$TMPDIR/test5_store.zip" 2>/dev/null || stat -f%z "$TMPDIR/test5_store.zip" 2>/dev/null)

log_info "Test 5b: Compression level 9 (best)"
$ZIPALIGN -9 "$TMPDIR/test5_deflate.zip" "$TMPDIR/zeros.bin"
DEFLATE_SIZE=$(stat -c%s "$TMPDIR/test5_deflate.zip" 2>/dev/null || stat -f%z "$TMPDIR/test5_deflate.zip" 2>/dev/null)

if [ "$DEFLATE_SIZE" -lt "$STORE_SIZE" ]; then
    log_pass "Compression reduces file size (store: $STORE_SIZE, deflate: $DEFLATE_SIZE)"
else
    log_fail "Compression should reduce size (store: $STORE_SIZE, deflate: $DEFLATE_SIZE)"
fi

########################################
# Test 6: Alignment verification (65536)
########################################
log_info "Test 6: Verify default alignment (65536)"
echo "ALIGNTEST6" > "$TMPDIR/align.txt"
$ZIPALIGN -0 "$TMPDIR/test6.zip" "$TMPDIR/align.txt"
# Find the offset where our data starts using od, strip leading zeros with expr
DATA_OFFSET=$(od -A d -c "$TMPDIR/test6.zip" | grep "A   L   I   G   N   T   E   S   T   6" | awk '{printf "%d", $1}')
if [ -n "$DATA_OFFSET" ] && [ "$((DATA_OFFSET % 65536))" -eq 0 ]; then
    log_pass "Data aligned to 65536 bytes (offset: $DATA_OFFSET)"
else
    log_fail "Data not aligned to 65536 bytes (offset: $DATA_OFFSET)"
fi

########################################
# Test 7: Custom alignment (-a 4096)
########################################
log_info "Test 7: Custom alignment (-a 4096)"
echo "ALIGNTEST7" > "$TMPDIR/align7.txt"
$ZIPALIGN -0 -a 4096 "$TMPDIR/test7.zip" "$TMPDIR/align7.txt"
DATA_OFFSET=$(od -A d -c "$TMPDIR/test7.zip" | grep "A   L   I   G   N   T   E   S   T   7" | awk '{printf "%d", $1}')
if [ -n "$DATA_OFFSET" ] && [ "$((DATA_OFFSET % 4096))" -eq 0 ]; then
    log_pass "Data aligned to 4096 bytes (offset: $DATA_OFFSET)"
else
    log_fail "Data not aligned to 4096 bytes (offset: $DATA_OFFSET)"
fi

########################################
# Test 7b: Custom alignment (-a 512)
########################################
log_info "Test 7b: Custom alignment (-a 512)"
echo "ALIGNTEST7B" > "$TMPDIR/align7b.txt"
$ZIPALIGN -0 -a 512 "$TMPDIR/test7b.zip" "$TMPDIR/align7b.txt"
DATA_OFFSET=$(od -A d -c "$TMPDIR/test7b.zip" | grep "A   L   I   G   N   T   E   S   T   7   B" | awk '{printf "%d", $1}')
if [ -n "$DATA_OFFSET" ] && [ "$((DATA_OFFSET % 512))" -eq 0 ]; then
    log_pass "Data aligned to 512 bytes (offset: $DATA_OFFSET)"
else
    log_fail "Data not aligned to 512 bytes (offset: $DATA_OFFSET)"
fi

########################################
# Test 8: Append to existing archive
########################################
log_info "Test 8: Append to existing archive"
echo "first file" > "$TMPDIR/first.txt"
echo "second file" > "$TMPDIR/second.txt"
$ZIPALIGN "$TMPDIR/test8.zip" "$TMPDIR/first.txt"
$ZIPALIGN "$TMPDIR/test8.zip" "$TMPDIR/second.txt"
COUNT=$(unzip -l "$TMPDIR/test8.zip" 2>/dev/null | grep -c '\.txt$' || true)
if [ "$COUNT" -eq 2 ]; then
    log_pass "Successfully appended to existing archive"
else
    log_fail "Failed to append to existing archive (found $COUNT files)"
fi

########################################
# Test 9: Replace existing file in archive
########################################
log_info "Test 9: Replace existing file in archive"
echo "original content" > "$TMPDIR/replace.txt"
$ZIPALIGN -j "$TMPDIR/test9.zip" "$TMPDIR/replace.txt"
echo "updated content" > "$TMPDIR/replace.txt"
$ZIPALIGN -j "$TMPDIR/test9.zip" "$TMPDIR/replace.txt"
mkdir -p "$TMPDIR/extract9"
unzip -q -o -d "$TMPDIR/extract9" "$TMPDIR/test9.zip"
if grep -q "updated content" "$TMPDIR/extract9/replace.txt" 2>/dev/null; then
    log_pass "Successfully replaced file in archive"
else
    log_fail "Failed to replace file in archive"
fi

########################################
# Test 10: Large file handling
########################################
log_info "Test 10: Large file handling (10MB)"
dd if=/dev/urandom bs=1048576 count=10 2>/dev/null > "$TMPDIR/large.bin"
ORIGINAL_SUM=$(sha256sum "$TMPDIR/large.bin" 2>/dev/null | cut -d' ' -f1 || shasum -a 256 "$TMPDIR/large.bin" | cut -d' ' -f1)
$ZIPALIGN -0 "$TMPDIR/test10.zip" "$TMPDIR/large.bin"
mkdir -p "$TMPDIR/extract10"
unzip -q -d "$TMPDIR/extract10" "$TMPDIR/test10.zip"
EXTRACTED_FILE=$(find "$TMPDIR/extract10" -name "large.bin" -type f | head -1)
if [ -n "$EXTRACTED_FILE" ]; then
    EXTRACTED_SUM=$(sha256sum "$EXTRACTED_FILE" 2>/dev/null | cut -d' ' -f1 || shasum -a 256 "$EXTRACTED_FILE" | cut -d' ' -f1)
    if [ "$ORIGINAL_SUM" = "$EXTRACTED_SUM" ]; then
        log_pass "Large file integrity verified"
    else
        log_fail "Large file checksum mismatch"
    fi
else
    log_fail "Large file not found in extracted archive"
fi

########################################
# Test 11: Binary file handling
########################################
log_info "Test 11: Binary file with all byte values"
# Create a file with all 256 byte values
i=0
: > "$TMPDIR/binary.bin"
while [ $i -lt 256 ]; do
    printf "\\$(printf '%03o' $i)" >> "$TMPDIR/binary.bin"
    i=$((i + 1))
done
$ZIPALIGN -0 "$TMPDIR/test11.zip" "$TMPDIR/binary.bin"
mkdir -p "$TMPDIR/extract11"
unzip -q -d "$TMPDIR/extract11" "$TMPDIR/test11.zip"
EXTRACTED_FILE=$(find "$TMPDIR/extract11" -name "binary.bin" -type f | head -1)
if [ -n "$EXTRACTED_FILE" ] && cmp -s "$TMPDIR/binary.bin" "$EXTRACTED_FILE"; then
    log_pass "Binary file with all byte values preserved"
else
    log_fail "Binary file corruption detected"
fi

########################################
# Test 12: Verbose flag (-v)
########################################
log_info "Test 12: Verbose flag (-v)"
echo "verbose test" > "$TMPDIR/verbose.txt"
OUTPUT=$($ZIPALIGN -v "$TMPDIR/test12.zip" "$TMPDIR/verbose.txt" 2>&1)
if echo "$OUTPUT" | grep -q "verbose.txt"; then
    log_pass "Verbose output shows filename"
else
    log_fail "Verbose output missing filename"
fi

########################################
# Test 13: Error handling - missing input
########################################
log_info "Test 13: Error handling - nonexistent input file"
if $ZIPALIGN "$TMPDIR/test13.zip" "$TMPDIR/nonexistent_file_12345.txt" 2>/dev/null; then
    log_fail "Should have failed on nonexistent input"
else
    log_pass "Correctly failed on nonexistent input"
fi

########################################
# Test 14: Error handling - invalid alignment
########################################
log_info "Test 14: Error handling - invalid alignment (not power of 2)"
if $ZIPALIGN -a 13 "$TMPDIR/test14.zip" "$TMPDIR/hello.txt" 2>/dev/null; then
    log_fail "Should have failed on non-power-of-2 alignment (13)"
else
    log_pass "Correctly failed on non-power-of-2 alignment (13)"
fi
if $ZIPALIGN -a 100 "$TMPDIR/test14b.zip" "$TMPDIR/hello.txt" 2>/dev/null; then
    log_fail "Should have failed on non-power-of-2 alignment (100)"
else
    log_pass "Correctly failed on non-power-of-2 alignment (100)"
fi

########################################
# Test 15: Unicode/UTF-8 content
########################################
log_info "Test 15: UTF-8 content handling"
printf "Hello \xc3\xa9\xc3\xa0\xc3\xbc \xe4\xb8\xad\xe6\x96\x87\n" > "$TMPDIR/utf8.txt"
$ZIPALIGN "$TMPDIR/test15.zip" "$TMPDIR/utf8.txt"
mkdir -p "$TMPDIR/extract15"
unzip -q -d "$TMPDIR/extract15" "$TMPDIR/test15.zip"
EXTRACTED_FILE=$(find "$TMPDIR/extract15" -name "utf8.txt" -type f | head -1)
if [ -n "$EXTRACTED_FILE" ] && cmp -s "$TMPDIR/utf8.txt" "$EXTRACTED_FILE"; then
    log_pass "UTF-8 content preserved"
else
    log_fail "UTF-8 content corrupted"
fi

########################################
# Test 16: Unicode filenames
########################################
log_info "Test 16: Unicode filenames"
echo "unicode filename test" > "$TMPDIR/café-日本語-émoji.txt"
$ZIPALIGN -j "$TMPDIR/test16.zip" "$TMPDIR/café-日本語-émoji.txt"
if unzip -l "$TMPDIR/test16.zip" 2>/dev/null | grep -q "café-日本語-émoji.txt"; then
    mkdir -p "$TMPDIR/extract16"
    unzip -q -d "$TMPDIR/extract16" "$TMPDIR/test16.zip"
    if [ -f "$TMPDIR/extract16/café-日本語-émoji.txt" ]; then
        log_pass "Unicode filename preserved"
    else
        log_fail "Unicode filename not extracted correctly"
    fi
else
    log_fail "Unicode filename not stored correctly in archive"
fi

########################################
# Summary
########################################
echo ""
echo "========================================"
printf "Test Results: ${GREEN}%d passed${NC}, ${RED}%d failed${NC}\n" "$PASS" "$FAIL"
echo "========================================"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
rm -rf "$TMPDIR"
exit 0
