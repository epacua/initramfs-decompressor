#!/usr/bin/env bash

if [[ $# -ne 1 ]]; then
    echo "Needs exactly one argument which must be an initramfs. Exiting..."
    exit 1
fi

GREP=$(which rg)
INITRD=$1
BLOCKS=()

function get_starting_block() {
    local start=$1
    $GREP -q cpio <(dd if=$INITRD skip=$start | file -b -)
    status=$?

    if (exit $status); then
        start=$(dd if=$INITRD skip=$start | cpio -idm --only-verify-crc 2>&1 | cut -d' '  -f1)
        echo $start
    fi
}

function while_blocks() {
    if [[ $1 =~ ^[0-9]+$ ]]; then
        BLOCKS+=( $1 )
    fi

    curr=$(get_starting_block $1)

    while [[ $curr =~ ^[0-9]+$ ]]; do
        curr=$(( ${BLOCKS[@]: -1} + $curr ))
        BLOCKS+=( $curr )
        curr=$(get_starting_block $curr)
    done
}

function decompress() {
    while_blocks 0

    for ((i=0; i<${#BLOCKS[@]};i++)) {
        start="${BLOCKS[i]}"
        blk=$(dd if=$INITRD skip=$start | file -b -)

        if [[ $blk =~ "cpio" ]]; then
            dd if=$INITRD skip=$start | cpio -idm
        elif [[ $blk =~ "Zstandard" ]]; then
            dd if=$INITRD skip=$start | unzstd > myfile
            if [[ $(file -b myfile) =~ "cpio" ]]; then
                cpio -idm < myfile
                sleep 0.5; rm myfile
            fi
        else
            echo "Unknown"
        fi
    }
}

decompress
unset i
