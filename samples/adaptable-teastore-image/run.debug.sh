#!/bin/bash

# 1. Récupérer Siphonix (jar, plugin AdaptiFlow, scénarios) s'il est absent
if [ ! -f ./siphonix-app.jar ] || [ ! -d ./plugins ] || [ ! -d ./scenarios ]; then
    ../../fetch-siphonix.sh || { echo "Erreur : la récupération de Siphonix a échoué." >&2; exit 1; }
fi

# 3. Build de l'image manuellement (docker compose ... up --build plante à l'étape interne
# "resolving provenance for metadata file" avec ce docker compose (bug connu), alors que le
# build lui-même reussit toujours. On builde donc avec `docker build` directement, qui n'a
# pas ce probleme, puis on laisse `up -d` (sans --build) demarrer avec l'image deja construite.
SIPHONIX_ARG="${SIPHONIX:-./siphonix-app.jar}"
if ! docker build -f Dockerfile.manager --build-arg SIPHONIX="$SIPHONIX_ARG" -t adaptable-teastore-image-image:latest .; then
    echo "Erreur : le build de l'image 'image' a echoue." >&2
    exit 1
fi

# 4. Lancement de docker-compose (sans --build, l'image vient d'etre construite ci-dessus)
docker-compose -f docker-compose.yml -p adaptable-teastore-image up -d