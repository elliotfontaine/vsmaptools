#!/bin/bash
source ~/mambaforge/etc/profile.d/conda.sh
conda activate vsmaptools

clear

# Crée un fichier de config temporaire avec le PS1 personnalisé
TMP_RC=$(mktemp)
cat <<EOF > "$TMP_RC"
PS1="\[\033[36m\]\u\[\033[m\]@\[\033[32m\]\[\033[33;1m\]\W\[\033[m\] \$ "
EOF

exec bash --rcfile "$TMP_RC"
