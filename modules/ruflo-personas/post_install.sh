#!/usr/bin/env bash
# Cappy — ruflo-personas post-install. Delegates to the setup script,
# which renders aliases at its end via alias-generator.sh.
exec bash "$(dirname "$0")/setup-ruflo-personas.sh"
