#!/usr/bin/env bash
DSTDIR="$2"

if [[ $# -gt 2 || $# -lt 1 ]]; then
    echo "Needs exactly one (initrd) or two (initrd and destination) arguments. Exiting..."
    exit 1
fi

if [[ $# -eq 2 ]]; then
    cd $DSTDIR
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

function process_blocks() {
    blk=0
    while [[ $blk =~ ^[0-9]+$ ]]; do
        file_type=$(dd if=$INITRD skip=$blk | file -b -)
        if [[ $file_type =~ "cpio archive" ]]; then
            next_blk=$(dd if=$INITRD skip=$blk | cpio -idm 2>&1 | cut -d' ' -f1)
        elif [[ $file_type =~ "Zstandard" ]]; then
            next_blk=$(dd if=$INITRD skip=$blk | unzstd > myfile)
            if [[ $(file -b myfile) =~ "cpio archive" ]]; then
                cpio -idm < myfile
                sleep 0.5; rm myfile
            else
                echo "Unknown file"
            fi
        else
            echo "Unknown"
        fi

        if [[ "$next_blk" =~ ^[0-9]+$ ]]; then
            blk=$(( next_blk + blk ))
        else
            break
        fi
    done
}

#decompress
process_blocks
unset i
