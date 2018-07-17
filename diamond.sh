#!/bin/bash

# - download nr as fasta from ncbi 
# - download ncbi taxonomy dump and protein accession->taxid mappings from ncbi
# - make diamond db
# - remove fasta data

./ncbidl.sh blast/db/FASTA pdbnt diamonddb/
./ncbidl.sh pub/taxonomy/ taxdump taxonomy/ncbi/
./ncbidl.sh pub/taxonomy/accession2taxid prot.accession2taxid.gz taxonomy/ncbi/

# use diamond from the galaxy cond env

##module purge
##module use ...
##module use diamond/0.9.21
. /home/berntm/miniconda3/bin/activate '/home/berntm/miniconda3/envs/__diamond@0.9.21'

diamond makedb --in diamonddb/latest/pdbn.fas --taxonmap taxonomy/ncbi/latest/accession2taxid/prot.accession2taxid --taxonnodes taxonomy/ncbi/latest/nodes.dmp --out diamonddb/latest/nr.dmnd

rm /data/db/diamonddb/*.fas
