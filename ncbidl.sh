#!/bin/bash

# ------------------------------------------------------------------------------
# configuration, arguments
# ------------------------------------------------------------------------------

umask 0022

function usage {
  echo "usage: bash $0 rdir pattern ldir"
  echo "- will download rdir/pattern.*.tar.gz from the NCBI ftp to ldir/YYYY-MM-DD"
  echo '- example call ./ncbidl.sh blast/db/ 16S /data/db/blastdb/'
}

# parse command line arguments (and make sure that they are set and useful)
REMOTE_DIR=$1
[[ -n $REMOTE_DIR ]] || {
  usage >&2
  exit 1
}

PATTERN=$2
[[ -n $PATTERN ]] || {
  usage >&2
  exit 1
}

LOCAL_DIR=$3
[[ -d $LOCAL_DIR ]] || {
  echo "no such file or directory "$LOCAL_DIR >&2
  usage >&2
  exit 1
}

DATE=$(date +%F)

# create data dir (and make sure its deleted if anything fails)
mkdir -p $LOCAL_DIR/$DATE/ &&
trap 'rm -rf $LOCAL_DIR/$DATE/' INT TERM
# create temp directory within the LOCAL_DIR and make sure its deleted on exit
TMP_DIR=$(mktemp -d --tmpdir=$LOCAL_DIR/ .ncbidl-XXXXXXXXXX)
trap 'rm -rf $TMP_DIR' EXIT INT TERM


# ------------------------------------------------------------------------------
# application functions
# ------------------------------------------------------------------------------

function log.info {
  logger -p user.info -t ncbidl "$@"
  >&2 echo "$@"
}

function log.err {
  logger -p user.err -t ncbidl "$@"
  >&2 echo "$@"
}

function ncbidl.download {
  # download all md5s first, then download all tarballs
  # using lftp's mirror (non-recursive, dont set permissions, parallel with include pattern)
  cat << EOF | lftp ftp://ftp.ncbi.nlm.nih.gov
set net:socket-buffer 33554432
mirror -r -p -P 8 -i "^$PATTERN.*(\.tar)?\.gz\.md5$" $REMOTE_DIR $TMP_DIR
mirror -r -p -P 8 -i "^$PATTERN.*(\.tar)?\.gz$"      $REMOTE_DIR $TMP_DIR
EOF
}

# ------------------------------------------------------------------------------
# application
# ------------------------------------------------------------------------------

log.info "starting download of $PATTERN database ..." &&
ncbidl.download &&
log.info "... download finished, checking md5 ..." &&
pushd $TMP_DIR &> /dev/null &&
md5sum --check --quiet *.md5 &&
log.info "... md5 success, extracting ..." &&
for i in $PATTERN*.gz ; do
  ( 
  if [[ $i =~ \.tar.gz$ ]]; then
    tar xzfo $i
  else
    gunzip -k $i
  fi 
  rm -f $i $i.md5 
  ) || exit 1
done &&
popd &> /dev/null
log.info "... extracting finished, moving ..." &&
for i in $TMP_DIR/* ; do
  mv -n $i $LOCAL_DIR/$DATE/ || exit 1
done &&
rm -rf $LOCAL_DIR/latest
ln -s $DATE/ $LOCAL_DIR/latest
log.info "... moving done, setting read only ..." &&
# chmod 555 $LOCAL_DIR/$DATE/ &&
# chmod 444 $LOCAL_DIR/$DATE/* &&
log.info "... set read only, done." 
