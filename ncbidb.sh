#!/bin/bash

# ------------------------------------------------------------------------------
# configuration, arguments
# ------------------------------------------------------------------------------

umask 0022

function usage {
  echo "usage: bash $0 rdir dbname ldir"
  echo "- will download rdir/dbname*.tar.gz from the NCBI ftp to ldir/dbname/YYYY-MM-DD"
}

# parse command line arguments (and make sure that they are set and useful)
REMOTE_DIR=$1
[[ -n $REMOTE_DIR ]] || {
  usage >&2
  exit 1
}

DB_NAME=$2
[[ -n $DB_NAME ]] || {
  usage >&2
  exit 1
}

LOCAL_DIR=$3
[[ -d $LOCAL_DIR ]] || {
  echo "no such file or directory "$LOCAL_DIR >&2
  usage >&2
  exit 1
}


mkdir -p $LOCAL_DIR/$DB_NAME &&

# create data dir (and make sure its deleted if anything fails)
mkdir $LOCAL_DIR/$DB_NAME/$DATE/ &&
trap 'rmdir $LOCAL_DIR/$DB_NAME/$DATE/' EXIT INT TERM
# create temp directory within the LOCAL_DIR and make sure its deleted on exit
TMP_DIR=$(mktemp -d --tmpdir=$LOCAL_DIR/$DBNAME .blastdl-XXXXXXXXXX)
trap 'rm -rf $TMP_DIR' EXIT INT TERM

DATE=$(date +%F)

# ------------------------------------------------------------------------------
# application functions
# ------------------------------------------------------------------------------

function log.info {
  logger -p user.info -t blastdl "$@"
}

function log.err {
  logger -p user.err -t blastdl "$@"
}

function blastdl.download {
  # download all md5s first, then download all tarballs
  # using lftp's mirror (non-recursive, dont set permissions, parallel with include pattern)
  cat << EOF | lftp ftp://ftp.ncbi.nlm.nih.gov
set net:socket-buffer 33554432
mirror -r -p -P 8 -i "^$DB_NAME.*\.tar\.gz\.md5$" $REMOTE_DIR $TMP_DIR
mirror -r -p -P 8 -i "^$DB_NAME.*\.tar\.gz$"      $REMOTE_DIR $TMP_DIR
EOF
}

# ------------------------------------------------------------------------------
# application
# ------------------------------------------------------------------------------

log.info "starting download of $DB_NAME database ..." &&
blastdl.download &&
log.info "... download finished, checking md5 ..." &&
pushd $TMP_DIR &> /dev/null &&
md5sum --check --quiet *.md5 &&
log.info "... md5 success, extracting ..." &&
for i in $DB_NAME*.tar.gz ; do
  tar xzfo $i || exit 1
  rm -f $i $i.md5
done &&
log.info "... extracting finished, moving ..." &&
for i in * ; do
  mv -n $i $LOCAL_DIR/$DB_NAME/$DATE/ || exit 1
done &&
rm -rf $LOCAL_DIR/$DB_NAME/latest
ln -s $LOCAL_DIR/$DB_NAME/$DATE/ $LOCAL_DIR/$DB_NAME/latest
log.info "... moving done, setting read only ..." &&
chmod 555 $LOCAL_DIR/$DB_NAME/$DATE/ &&
chmod 444 $LOCAL_DIR/$DB_NAME/$DATE/* &&
log.info "... set read only, done." &&
popd &> /dev/null
