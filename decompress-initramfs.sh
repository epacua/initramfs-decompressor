#!/usr/bin/env bash

if [[ $# -gt 2 || $# -lt 1 ]]; then
    echo "Needs exactly one (initrd) or two (initrd and destination dir) arguments. Exiting..."
    exit 1
fi

GREP=$(which rg)
INITRD=$(readlink -qe $1)
DSTDIR="$2"
BLOCKS=()

if [[ $# -eq 2 && -d "$DSTDIR" ]]; then
    echo "Changing directory to $DSTDIR"
    cd $DSTDIR
else
    echo "Directory $DSTDIR does not exist. Exiting..."
    exit 1
fi

function decompress_archive() {
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

decompress_archive
unset i
