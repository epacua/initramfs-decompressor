#!/usr/bin/env bash

function prerun_checks() {
    if [[ $# -gt 2 || $# -lt 1 ]]; then
        echo "This script accepts one (initrd) or two arguments (if destdir is supplied) only."
        cat <<- EOF

        Usage:
            $(basename ${BASH_ARGV0}) <initramfs>
            $(basename ${BASH_ARGV0}) <initramfs> <dstdir>
EOF
        exit 1
    fi

    if !($GREP -qo 'cpio\|gzip\|LZMA\|Zstandard' <(file -b $INITRAMFS)); then
        cat <<- EOF
        Argument 1 is not an initramfs

        Usage:
            $(basename ${BASH_ARGV0}) <initramfs>
            $(basename ${BASH_ARGV0}) <initramfs> <dstdir>
EOF
        exit 1
    fi

    if !([[ -d $DSTDIR ]]); then
        cat <<- EOF
        Argument 2 is not a directory

        Usage:
            $(basename ${BASH_ARGV0}) <initramfs>
            $(basename ${BASH_ARGV0}) <initramfs> <dstdir>
EOF
        exit 1
    fi
}

GREP=$(which grep)
INITRAMFS=$(readlink -qe $1)
DSTDIR=${2:-$(pwd)} # This handles if directory is given via $2
BLOCKS=()


function decompress_archive() {
    cd $DSTDIR
    blk=0
    while [[ $blk =~ ^[0-9]+$ ]]; do
        file_type=$(dd if=$INITRAMFS skip=$blk | file -b -)
        if [[ $file_type =~ "cpio archive" ]]; then
            next_blk=$(dd if=$INITRAMFS skip=$blk | cpio -idm 2>&1 | cut -d' ' -f1)

        elif [[ $file_type =~ "Zstandard" ]]; then
            next_blk=$(dd if=$INITRAMFS skip=$blk | unzstd > myarchive)
            if [[ $(file -b myarchive) =~ "cpio archive" ]]; then
                cpio -idm < myarchive
                rm myarchive
            else
                echo "Unknown file type or archive"
            fi

        elif [[ $file_type =~ "LZMA" ]]; then
            next_blk=$(dd if=$INITRAMFS skip=$blk | unlzma > myarchive)
            if [[ $(file -b myarchive) =~ "cpio archive" ]]; then
                cpio -idm < myarchive
                rm myarchive
            else
                echo "Unknown file type or archive"
            fi

        elif [[ $file_type =~ "gzip" ]]; then
            next_blk=$(dd if=$INITRAMFS skip=$blk | gunzip > myarchive)
            if [[ $(file -b myarchive) =~ "cpio archive" ]]; then
                cpio -idm < myarchive
                rm myarchive
            else
                echo "Unknown file type or archive"
            fi
        else
            echo "Unknown file type or archive"
        fi

        if [[ "$next_blk" =~ ^[0-9]+$ ]]; then
            blk=$(( next_blk + blk ))
        else
            break
        fi
    done
}

prerun_checks "$@" # Checks all the command-line parameters
decompress_archive
unset i
